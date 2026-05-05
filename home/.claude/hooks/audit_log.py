#!/usr/bin/env python3
"""Claude Code 監査ログ用フック (全イベント対応)。

設計:
  - 全イベント (PreToolUse / PostToolUse / UserPromptSubmit / SessionStart /
    SessionEnd / Notification / Stop / SubagentStop / PreCompact) を
    ~/.claude/logs/audit/YYYY-MM-DD.jsonl に JSON Lines で追記する。
  - インシデント証跡として「いつ・誰が・何を・どこへ」を再構成可能にする。
  - 機密情報はキー名ベース + 既知トークン形式 + ヘッダー/URL マスキングで除去。
  - 並行書き込みは fcntl.flock(LOCK_EX) で直列化、書き込みは os.write 1 回で原子化。
  - 各レコードは prev_hash/rec_hash の hash chain で改ざん検出を可能にする。
  - フック自身のバグでツール実行を妨げないことを最優先 (既定 fail-open / exit 0)。
  - AUDIT_LOG_STRICT=1 のとき、PreToolUse かつ external_access のレコード書き込み
    失敗時のみ exit 2 でブロックする厳格モード。

入出力:
  - stdin: Claude Code から渡されるイベント payload (JSON)。
  - stdout: 通常は出力なし。
  - exit code: 0 (正常 / フォールスルー)、2 (strict ブロック時のみ)。

環境変数:
  - AUDIT_LOG_DIR: ログ出力ディレクトリの上書き (テスト用、未設定なら既定)。
  - AUDIT_LOG_STRICT: "1" のとき strict モード。
  - CLAUDE_CODE_VERSION: あればレコードに記録。
"""

from __future__ import annotations

import fcntl
import getpass
import hashlib
import json
import os
import re
import shlex
import socket
import sys
from datetime import datetime, timezone
from typing import Any
from urllib.parse import urlparse

# ------------------------------- 定数 -------------------------------

DEFAULT_LOG_DIR = os.path.expanduser("~/.claude/logs/audit")

# 1 レコードのシリアライズ後最大サイズ。超過時は tool_input を縮退する。
MAX_RECORD_BYTES = 32 * 1024

ZERO_HASH = "0" * 64
BROKEN_HASH = "BROKEN_CHAIN"

# ----------------------------- マスキング -----------------------------

# dict のキー名 (lowercase) を `_` / `-` で分割した結果に「これらのいずれか」が含まれる場合、
# 値を "***" に置換する。部分一致 (`"author"` で `"auth"` ヒット等) を避けるため、token 単位で照合する。
SECRET_KEY_TOKENS = frozenset({
    "password", "passwd", "secret", "token", "apikey",
    "authorization", "cookie", "bearer", "key",
    # 複合: `api_key` → ["api", "key"], `aws_secret_access_key` → ["aws","secret","access","key"]
    # → "secret" / "key" のいずれかでヒット
})

# 完全一致で必ずマスクするキー名 (token 分割で曖昧になりやすい複合語の救済)
SECRET_KEY_EXACT = frozenset({
    "auth", "api_key", "access_key", "private_key", "secret_key",
    "client_secret", "refresh_token", "access_token", "id_token",
    "aws_secret_access_key", "aws_access_key_id",
})

# 過剰マスクを避けるため明示的にマスク対象外とするキー名 (機密ではない一般用語)
SECRET_KEY_ALLOWLIST = frozenset({
    "tokens", "max_tokens", "input_tokens", "output_tokens",
    "token_count", "input_token_count", "output_token_count",
    "cache_creation_input_tokens", "cache_read_input_tokens",
    "key_count", "keys_count", "num_keys",
})

# 文字列値に対する置換パターン。先に書いたものほど優先 (より具体的なものを先に)。
MASK_PATTERNS: list[tuple[re.Pattern[str], str]] = [
    # PEM ブロック (改行を含むため DOTALL ではなく [\s\S] で受ける)
    (re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----"),
     "***PEM***"),

    # .netrc 形式
    (re.compile(r"machine\s+(\S+)\s+login\s+\S+\s+password\s+\S+", re.IGNORECASE),
     r"machine \1 login *** password ***"),

    # Authorization / Proxy-Authorization ヘッダ (行末・クォート・閉じ括弧まで)
    (re.compile(r"((?:Proxy-)?Authorization)\s*:\s*[^\r\n\"'\\]*", re.IGNORECASE),
     r"\1: ***"),

    # X-API-Key / X-Auth-Token / X-Access-Token
    (re.compile(r"(X-(?:API-Key|Auth-Token|Access-Token))\s*:\s*[^\r\n\"'\\]*", re.IGNORECASE),
     r"\1: ***"),

    # Cookie / Set-Cookie
    (re.compile(r"((?:Set-)?Cookie)\s*:\s*[^\r\n\"'\\]*", re.IGNORECASE),
     r"\1: ***"),

    # URL 内クレデンシャル: scheme://user:pass@
    (re.compile(r"(https?|ftp|s3|gs|postgres|postgresql|mysql|redis|mongodb|amqp)://[^/\s:@]+:[^/\s@]+@",
                re.IGNORECASE),
     r"\1://***:***@"),

    # クエリ文字列 ?token=xxx, &access_token=xxx, &api_key=xxx 等
    (re.compile(r"([?&](?:token|access_token|client_secret|api_key|apikey|key|sig|signature))=[^&\s\"']*",
                re.IGNORECASE),
     r"\1=***"),

    # JWT (3 セグメントで各 16 文字以上、典型的な aaa.bbb.ccc)
    (re.compile(r"\b[A-Za-z0-9_-]{16,}\.[A-Za-z0-9_-]{16,}\.[A-Za-z0-9_-]{16,}\b"),
     "***JWT***"),

    # AWS Access Key
    (re.compile(r"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b"),
     "***AWSKEY***"),

    # OpenAI / Anthropic API キー (sk-, sk-proj-, sk-ant-)
    (re.compile(r"\bsk-(?:proj-|ant-(?:api\d+-)?)?[A-Za-z0-9_\-]{20,}\b"),
     "***"),

    # GitHub PAT 系 (ghp/gho/ghs/ghu/ghr/github_pat)
    (re.compile(r"\b(?:ghp|gho|ghs|ghu|ghr)_[A-Za-z0-9]{16,}\b"),
     "***"),
    (re.compile(r"\bgithub_pat_[A-Za-z0-9_]{16,}\b"),
     "***"),

    # GitLab PAT
    (re.compile(r"\bglpat-[A-Za-z0-9_\-]{16,}\b"),
     "***"),

    # Slack tokens
    (re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{10,}\b"),
     "***"),

    # npm token
    (re.compile(r"\bnpm_[A-Za-z0-9]{36,}\b"),
     "***"),

    # PyPI token
    (re.compile(r"\bpypi-[A-Za-z0-9_\-]{16,}\b"),
     "***"),

    # Google API key
    (re.compile(r"\bAIza[0-9A-Za-z_\-]{35}\b"),
     "***"),

    # Stripe (live/test, sk_/rk_)
    (re.compile(r"\b(?:sk|rk)_(?:live|test)_[A-Za-z0-9]{16,}\b"),
     "***"),

    # 環境変数代入 KEY=VALUE で KEY が機密候補のもの (大文字英数の env 命名規則を想定)。
    # 値は quoted ("..." / '...') / 非 quote (\S+) 両対応で、空白を含む値も丸ごと潰す。
    # プレフィックスは任意 (PASSWORD= 単独, DB_PASSWORD= 等の両方を捕捉)。
    (re.compile(
        r"((?:export\s+)?(?:[A-Z][A-Z_0-9]*)?"
        r"(?:SECRET|TOKEN|PASSWORD|PASSWD|API_KEY|APIKEY|PRIVATE_KEY|ACCESS_KEY|AUTH)"
        r"[A-Z_0-9]*\s*=)"
        r"(?:\"[^\"]*\"|'[^']*'|\S+)"
    ),
     r"\1***"),
]


def _mask_string(s: str) -> str:
    if not s:
        return s
    for pat, repl in MASK_PATTERNS:
        s = pat.sub(repl, s)
    return s


_KEY_SPLIT_RE = re.compile(r"[_\-\s]+")


def _is_secret_key_name(k: str) -> bool:
    if not isinstance(k, str):
        return False
    kl = k.lower()
    if kl in SECRET_KEY_ALLOWLIST:
        return False
    if kl in SECRET_KEY_EXACT:
        return True
    tokens = set(_KEY_SPLIT_RE.split(kl))
    if tokens & SECRET_KEY_TOKENS:
        return True
    return False


def mask_secrets(value: Any) -> Any:
    """値を再帰走査して機密情報を `***` に置換した新しいオブジェクトを返す。"""
    if isinstance(value, dict):
        out: dict[Any, Any] = {}
        for k, v in value.items():
            if _is_secret_key_name(k) and v not in (None, "", [], {}):
                out[k] = "***"
            else:
                out[k] = mask_secrets(v)
        return out
    if isinstance(value, list):
        return [mask_secrets(v) for v in value]
    if isinstance(value, tuple):
        return tuple(mask_secrets(v) for v in value)
    if isinstance(value, str):
        return _mask_string(value)
    return value


# --------------------------- 外部アクセス判定 ---------------------------

# 単純なコマンド名で外部アクセスとみなすもの (basename 比較)。
NETWORK_COMMANDS = frozenset({
    "curl", "wget", "http", "https", "aria2c",
    "nc", "ncat", "socat",
    "ssh", "scp", "sftp", "rsync", "ftp",
    "dig", "nslookup", "host", "whois", "ping", "traceroute", "tracepath", "nmap",
    "telnet",
})

# サブコマンドで外部アクセスとみなすもの。(コマンド名, {外部サブコマンド})
NETWORK_SUBCMD_RULES: list[tuple[str, frozenset[str]]] = [
    ("git",      frozenset({"push", "pull", "fetch", "clone", "ls-remote"})),
    ("docker",   frozenset({"pull", "push", "login", "search"})),
    ("podman",   frozenset({"pull", "push", "login", "search"})),
    ("npm",      frozenset({"install", "i", "ci", "publish", "audit", "outdated", "update"})),
    ("pnpm",     frozenset({"install", "i", "add", "publish", "outdated", "update"})),
    ("yarn",     frozenset({"install", "add", "publish", "outdated", "upgrade"})),
    ("pip",      frozenset({"install", "download", "search"})),
    ("pip3",     frozenset({"install", "download", "search"})),
    ("uv",       frozenset({"add", "pip", "sync"})),
    ("go",       frozenset({"get", "install", "mod"})),
    ("cargo",    frozenset({"install", "fetch", "publish", "search"})),
    ("brew",     frozenset({"install", "fetch", "update", "upgrade", "search", "tap"})),
    ("gem",      frozenset({"install", "fetch", "push"})),
    ("apt",      frozenset({"install", "update", "upgrade"})),
    ("apt-get",  frozenset({"install", "update", "upgrade"})),
]

# サブコマンド問わず外部前提とみなす CLI ツール。
NETWORK_CLIS = frozenset({
    "gh", "glab", "aws", "gcloud", "az", "kubectl", "helm", "terraform",
    "openssl",
})

# block-push-to-main.py と同等のシェル制御演算子・サブシェル展開のための識別子。
SHELL_BREAKS = {"&&", "||", ";", "|", "&", "(", ")", "{", "}", "\n"}
SHELL_NAMES = {"bash", "sh", "zsh", "dash", "ksh"}
SHELL_C_FLAGS = {"-c", "-lc", "-cl", "-ic", "-ci", "-l"}

# Bash command 内の追加検出パターン。
URL_RE = re.compile(r"\b((?:https?|ftp|s3|gs)://[^\s\"'`]+)", re.IGNORECASE)
DEV_TCP_RE = re.compile(r"/dev/(?:tcp|udp)/[^/\s]+/\d+")
SCRIPT_INLINE_NET_RE = re.compile(
    r"\b(?:python\d?|node|ruby|perl)\s+-(?:c|e)\b"
    r"[\s\S]*?"
    r"\b(?:requests|urllib|httplib|http\.client|http\.get|fetch\(|Net::HTTP|net/http|open-uri|"
    r"socket\.(?:socket|create_connection))",
    re.IGNORECASE,
)


def expand_shell_wrappers(tokens: list[str]) -> list[str]:
    """`bash -c 'inner'` のようなサブシェル呼び出しを 1 段だけ展開する。"""
    out: list[str] = []
    i = 0
    n = len(tokens)
    while i < n:
        t = tokens[i]
        if t in SHELL_NAMES and i + 2 < n and tokens[i + 1] in SHELL_C_FLAGS:
            try:
                inner = shlex.split(tokens[i + 2], posix=True)
            except ValueError:
                inner = []
            out.extend(inner)
            # 展開した bash -c 'inner' 以降は positional とみなされうるが、
            # 内部から見ると $0/$1 等で本体ではないため捨てる。
            i = n
            continue
        out.append(t)
        i += 1
    return out


def _command_basename(token: str) -> str:
    return os.path.basename(token)


def _bash_external_match(command: str) -> str | None:
    """Bash command 文字列が外部アクセスを示すなら理由文字列を返す。

    URL リテラル単体での判定は false positive (echo "https://x" や grep URL ファイル) を
    招くため行わない。URL の構造抽出は extract_external_targets 側で
    実コマンド (curl/wget/git clone 等) と一緒に登場した場合のみ行う。
    """
    if DEV_TCP_RE.search(command):
        return "dev_tcp"
    if SCRIPT_INLINE_NET_RE.search(command):
        return "script_inline"

    try:
        tokens = shlex.split(command, posix=True)
    except ValueError:
        return None
    tokens = expand_shell_wrappers(tokens)
    n = len(tokens)
    i = 0
    while i < n:
        if tokens[i] in SHELL_BREAKS:
            i += 1
            continue
        # 1 セクション (次の SHELL_BREAKS まで) の境界を確定する。
        sec_end = i
        while sec_end < n and tokens[sec_end] not in SHELL_BREAKS:
            sec_end += 1
        section = tokens[i:sec_end]

        match = _match_network_in_section(section)
        if match:
            return match
        i = sec_end + 1
    return None


_WRAPPER_NAMES = frozenset({"env", "command", "sudo", "doas", "exec", "nohup", "time", "stdbuf", "ionice", "nice"})


def _match_network_in_section(section: list[str]) -> str | None:
    """1 セクション内の token 列から、最初に登場するネット系コマンドを検出する。

    wrapper (sudo/env/time/...) 経由でも、それらの flag や value を構文解析せずにスキャンするだけで
    実コマンドを発見する。wrapper の flag が 1-token 値を伴う場合 (sudo -u user) でも、
    値を取り違えて誤分類することがない。
    """
    for j, tok in enumerate(section):
        bn = _command_basename(tok)
        # wrapper 名そのものはスキャン対象から外す (誤検出回避)
        if bn in _WRAPPER_NAMES:
            continue
        # FOO=bar 形式の env-style 代入もスキップ
        if "=" in tok and not tok.startswith("=") and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", tok):
            continue
        if bn in NETWORK_COMMANDS:
            return f"cmd:{bn}"
        if bn in NETWORK_CLIS:
            return f"cli:{bn}"
        for rule_cmd, subs in NETWORK_SUBCMD_RULES:
            if bn == rule_cmd and j + 1 < len(section) and section[j + 1] in subs:
                return f"{bn}:{section[j + 1]}"
    return None


def is_external_access(tool_name: str, tool_input: dict) -> tuple[bool, str | None]:
    """外部アクセス判定。(is_external, reason) を返す。"""
    if tool_name in ("WebFetch", "WebSearch"):
        return True, f"tool:{tool_name}"
    if tool_name and tool_name.startswith("mcp__"):
        return True, f"mcp:{tool_name}"
    if tool_name == "Bash":
        cmd = (tool_input or {}).get("command")
        if isinstance(cmd, str):
            reason = _bash_external_match(cmd)
            if reason:
                return True, f"bash:{reason}"
    return False, None


def _parse_url_target(url: str) -> dict | None:
    try:
        p = urlparse(url)
    except Exception:
        return None
    if not p.hostname:
        return None
    port = p.port
    if port is None:
        port = {"http": 80, "https": 443, "ftp": 21}.get(p.scheme)
    return {"scheme": p.scheme, "host": p.hostname, "port": port, "source": "url"}


def extract_external_targets(tool_name: str, tool_input: dict) -> list[dict]:
    """外部アクセス先を可能な範囲で構造化抽出する。"""
    targets: list[dict] = []
    ti = tool_input or {}

    if tool_name == "WebFetch":
        url = ti.get("url") or ""
        if isinstance(url, str) and url:
            t = _parse_url_target(url)
            if t:
                targets.append(t)
    elif tool_name == "WebSearch":
        targets.append({"type": "search", "tool": tool_name})
    elif tool_name and tool_name.startswith("mcp__"):
        targets.append({"type": "mcp", "tool": tool_name})
    elif tool_name == "Bash":
        cmd = ti.get("command")
        if isinstance(cmd, str):
            for m in URL_RE.finditer(cmd):
                t = _parse_url_target(m.group(1))
                if t:
                    targets.append(t)
            try:
                tokens = expand_shell_wrappers(shlex.split(cmd, posix=True))
            except ValueError:
                tokens = []
            for i, t in enumerate(tokens):
                if t == "git" and i + 1 < len(tokens) and tokens[i + 1] in {"push", "pull", "fetch", "clone", "ls-remote"}:
                    j = i + 2
                    while j < len(tokens):
                        if not tokens[j].startswith("-") and tokens[j] not in SHELL_BREAKS:
                            targets.append({"type": "git_remote", "remote": tokens[j], "subcmd": tokens[i + 1]})
                            break
                        j += 1

    # 重複除去 (host/port/scheme が同じものは 1 つに)。
    seen = set()
    deduped: list[dict] = []
    for t in targets:
        key = json.dumps(t, sort_keys=True)
        if key in seen:
            continue
        seen.add(key)
        deduped.append(t)
    return deduped


# ---------------------------- レコード組み立て ----------------------------

def _now_ts() -> str:
    """ISO 8601 UTC ミリ秒精度。"""
    now = datetime.now(timezone.utc)
    return now.strftime("%Y-%m-%dT%H:%M:%S.") + f"{now.microsecond // 1000:03d}Z"


def _common_fields(payload: dict) -> dict:
    try:
        ppid = os.getppid()
    except Exception:
        ppid = -1
    fields = {
        "ts": _now_ts(),
        "event": payload.get("hook_event_name", "") or "",
        "session_id": payload.get("session_id", "") or "",
        "cwd": payload.get("cwd", "") or "",
        "transcript_path": payload.get("transcript_path", "") or "",
        "user": getpass.getuser(),
        "uid": os.getuid(),
        "hostname": socket.gethostname(),
        "pid": os.getpid(),
        "ppid": ppid,
    }
    cv = os.environ.get("CLAUDE_CODE_VERSION")
    if cv:
        fields["claude_version"] = cv
    return fields


def summarize_response(tool_response: Any) -> dict:
    """tool_response を sha256 / バイト数 / 行数 に圧縮 (スニペットは保存しない)。"""
    if tool_response is None:
        return {"sha256": "", "bytes": 0, "lines": 0}
    if isinstance(tool_response, (dict, list)):
        text = json.dumps(tool_response, ensure_ascii=False, sort_keys=True)
    else:
        text = str(tool_response)
    b = text.encode("utf-8", errors="replace")
    nl = text.count("\n")
    lines = nl + (1 if text and not text.endswith("\n") else 0)
    return {
        "sha256": hashlib.sha256(b).hexdigest(),
        "bytes": len(b),
        "lines": lines,
    }


def _attach_external(record: dict, tool_name: str, tool_input: dict) -> None:
    ext, reason = is_external_access(tool_name, tool_input)
    record["external_access"] = ext
    if ext:
        record["external_reason"] = reason
        targets = extract_external_targets(tool_name, tool_input)
        if targets:
            record["external_targets"] = mask_secrets(targets)


def build_record(payload: dict) -> dict:
    """stdin payload からレコード本体 (rec_hash / prev_hash 抜き) を組み立てる。"""
    record = _common_fields(payload)
    event = record["event"]
    raw_input = payload.get("tool_input") or {}

    if event == "PreToolUse":
        record["tool_name"] = payload.get("tool_name", "") or ""
        record["tool_input"] = mask_secrets(raw_input)
        _attach_external(record, record["tool_name"], raw_input)
    elif event == "PostToolUse":
        record["tool_name"] = payload.get("tool_name", "") or ""
        record["tool_input"] = mask_secrets(raw_input)
        record["tool_response"] = summarize_response(payload.get("tool_response"))
        _attach_external(record, record["tool_name"], raw_input)
    elif event == "UserPromptSubmit":
        record["prompt"] = mask_secrets(payload.get("prompt", "") or "")
    elif event == "SessionStart":
        record["source"] = payload.get("source", "") or ""
    elif event == "SessionEnd":
        record["reason"] = payload.get("reason", "") or ""
    elif event in ("Stop", "SubagentStop"):
        record["stop_hook_active"] = bool(payload.get("stop_hook_active", False))
    elif event == "Notification":
        record["message"] = mask_secrets(payload.get("message", "") or "")
    elif event == "PreCompact":
        record["trigger"] = payload.get("trigger", "") or ""
        record["custom_instructions"] = mask_secrets(payload.get("custom_instructions", "") or "")

    return record


def _shrink_field(record: dict, key: str) -> bool:
    """record[key] を `_truncated` 構造に置換する。置換した場合は True。"""
    val = record.get(key)
    if val is None:
        return False
    try:
        text = json.dumps(val, ensure_ascii=False, sort_keys=True) if isinstance(val, (dict, list)) else str(val)
    except Exception:
        text = str(val)
    b = text.encode("utf-8", errors="replace")
    preview_keys = list(val.keys())[:20] if isinstance(val, dict) else []
    record[key] = {
        "_truncated": True,
        "sha256": hashlib.sha256(b).hexdigest(),
        "bytes": len(b),
        "preview_keys": preview_keys,
    }
    return True


# サイズ縮退の対象フィールド (大きくなりやすい順)。先頭から試して
# レコードが MAX_RECORD_BYTES 以下になった時点で打ち切る。
_TRUNCATABLE_FIELDS = ("tool_input", "tool_response", "prompt", "custom_instructions", "message")


def _record_size(record: dict) -> int:
    return len(json.dumps(record, ensure_ascii=False, separators=(",", ":")).encode("utf-8"))


def truncate_if_oversized(record: dict) -> dict:
    """シリアライズ後サイズが MAX_RECORD_BYTES を超えれば、巨大フィールドを順に縮退する。

    対象フィールド: tool_input / tool_response / prompt / custom_instructions / message。
    UserPromptSubmit や PreCompact のように tool_input がない event でも、prompt 等が
    巨大な場合に同等の縮退を行うことで、後段の hash chain 読み戻しが安定する。
    """
    if _record_size(record) <= MAX_RECORD_BYTES:
        return record
    for key in _TRUNCATABLE_FIELDS:
        if key in record:
            _shrink_field(record, key)
            if _record_size(record) <= MAX_RECORD_BYTES:
                return record
    return record


# -------------------------- ハッシュチェーン + 書き込み --------------------------

def sha256_canonical(record: dict) -> str:
    """rec_hash 抜きのレコード本体の canonical SHA256 を計算する。"""
    body = {k: v for k, v in record.items() if k != "rec_hash"}
    s = json.dumps(body, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(s.encode("utf-8")).hexdigest()


def read_last_rec_hash(fd: int) -> str:
    """ファイル末尾の最終レコードから rec_hash を取得する。

    Returns:
      ZERO_HASH: ファイル空 / 取得不能
      BROKEN_HASH: 末尾行が壊れている (chain 切れ検出シグナル)

    実装メモ:
      最終行は MAX_RECORD_BYTES (32KB) 程度になり得るため、見つけるまで
      末尾から chunk 単位で後方に追加読みする。chunk は MAX_RECORD_BYTES 相当に取る。
    """
    try:
        size = os.fstat(fd).st_size
    except OSError:
        return ZERO_HASH
    if size == 0:
        return ZERO_HASH

    chunk = max(MAX_RECORD_BYTES, 32 * 1024)
    cap = max(size, MAX_RECORD_BYTES * 8)  # 安全側の上限。極端に大きい単一行は諦める
    buf = b""
    pos = size
    try:
        while pos > 0 and len(buf) < cap:
            read_from = max(0, pos - chunk)
            os.lseek(fd, read_from, os.SEEK_SET)
            piece = os.read(fd, pos - read_from)
            buf = piece + buf
            pos = read_from
            # 末尾改行を除去した上で、内側に \n があるか (= 完全な最終行が見つかったか)
            tail = buf[:-1] if buf.endswith(b"\n") else buf
            if b"\n" in tail:
                break
        os.lseek(fd, 0, os.SEEK_END)
    except OSError:
        return ZERO_HASH

    if not buf:
        return ZERO_HASH
    if buf.endswith(b"\n"):
        buf = buf[:-1]
    nl = buf.rfind(b"\n")
    last_line = buf[nl + 1:] if nl >= 0 else buf
    try:
        last = json.loads(last_line.decode("utf-8", errors="replace"))
        rh = last.get("rec_hash")
        if isinstance(rh, str) and len(rh) == 64:
            return rh
    except Exception:
        pass
    return BROKEN_HASH


def _today_utc() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


def log_path_for_today(log_dir: str) -> str:
    return os.path.join(log_dir, f"{_today_utc()}.jsonl")


def ensure_log_dir(log_dir: str) -> None:
    os.makedirs(log_dir, mode=0o700, exist_ok=True)
    try:
        os.chmod(log_dir, 0o700)
    except OSError:
        pass


def _write_all(fd: int, data: bytes) -> None:
    """os.write は short write の可能性があるため、全バイト書き切るまでループする。

    途中失敗で部分行が残ると hash chain が壊れるため、ここで完全書き込みを保証する。
    """
    view = memoryview(data)
    n = len(view)
    sent = 0
    while sent < n:
        written = os.write(fd, view[sent:])
        if written <= 0:
            raise OSError(f"os.write returned {written} (sent {sent}/{n})")
        sent += written


def write_record(record: dict, log_dir: str | None = None) -> None:
    """レコードを日付別ファイルに追記する。hash chain も完成させる。"""
    log_dir = log_dir or os.environ.get("AUDIT_LOG_DIR") or DEFAULT_LOG_DIR
    ensure_log_dir(log_dir)
    record = truncate_if_oversized(record)
    path = log_path_for_today(log_dir)
    # O_RDWR: 末尾レコードを読み戻して prev_hash を取るため読み権限も必要。
    # O_APPEND: 並行プロセスでも write は常にファイル末尾へ追記される。
    # O_NOFOLLOW: ログファイルが symlink にすり替えられても追従しない。
    flags = os.O_RDWR | os.O_CREAT | os.O_APPEND | getattr(os, "O_NOFOLLOW", 0)
    fd = os.open(path, flags, 0o600)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX)
        # 既存ファイルが緩いパーミッションだった場合に正規化する (open mode は新規作成時のみ効くため)
        try:
            os.fchmod(fd, 0o600)
        except OSError:
            pass
        prev = read_last_rec_hash(fd)
        record["prev_hash"] = prev
        record["rec_hash"] = sha256_canonical(record)
        line = (json.dumps(record, ensure_ascii=False, separators=(",", ":")) + "\n").encode("utf-8")
        _write_all(fd, line)
    finally:
        try:
            fcntl.flock(fd, fcntl.LOCK_UN)
        except OSError:
            pass
        os.close(fd)


# ------------------------------- main -------------------------------

def _strict_should_block(record: dict) -> bool:
    return (
        os.environ.get("AUDIT_LOG_STRICT") == "1"
        and record.get("event") == "PreToolUse"
        and record.get("external_access") is True
    )


def _log_internal_error(message: str, log_dir: str) -> None:
    try:
        ensure_log_dir(log_dir)
        err_path = os.path.join(log_dir, "_errors.log")
        flags = os.O_WRONLY | os.O_CREAT | os.O_APPEND | getattr(os, "O_NOFOLLOW", 0)
        fd = os.open(err_path, flags, 0o600)
        try:
            os.write(fd, (_now_ts() + " " + message + "\n").encode("utf-8", errors="replace"))
        finally:
            os.close(fd)
    except Exception:
        # エラー記録自身も失敗したら諦める (ツール実行を妨げない)
        pass


def main() -> None:
    log_dir = os.environ.get("AUDIT_LOG_DIR") or DEFAULT_LOG_DIR
    try:
        raw = sys.stdin.read()
        payload = json.loads(raw) if raw and raw.strip() else {}
    except Exception as e:
        _log_internal_error(f"stdin parse error: {e!r}", log_dir)
        sys.exit(0)
    if not isinstance(payload, dict):
        _log_internal_error(f"payload not a dict: {type(payload).__name__}", log_dir)
        sys.exit(0)

    try:
        record = build_record(payload)
    except Exception as e:
        _log_internal_error(f"build_record error: {e!r}", log_dir)
        sys.exit(0)

    try:
        write_record(record, log_dir)
    except Exception as e:
        _log_internal_error(f"write_record error: {e!r}", log_dir)
        if _strict_should_block(record):
            print(f"audit-log: write failed for external_access event: {e}", file=sys.stderr)
            sys.exit(2)
    sys.exit(0)


if __name__ == "__main__":
    main()
