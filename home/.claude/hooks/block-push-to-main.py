#!/usr/bin/env python3
"""Claude Code PreToolUse フック: main / master ブランチへの git push をブロックする。

スコープ:
  - Claude Code 経由の Bash 実行のみが対象。手元のシェル / GUI / CI 等からの push は影響しない。
  - 「Claude Code が main/master へ直接 push する事故を防ぐ」用途のガード。
    最終防衛線ではないので、git 自体の安全装置 (保護ブランチ等) と併用が望ましい。

旧 sh 実装からの改善点:
  - `\\b(main|master)\\b` 正規表現の誤検知 (例: feature/main-fix) を解消
  - long flag (`--tags`, `--force-with-lease` 等) 取りこぼしを解消
  - `HEAD:main` / `:main` (削除) / `--delete main` / `refs/heads/main` / `+main` 等の refspec を構造的に扱う
  - jq 依存を排し、Python 標準ライブラリ (json, shlex) のみで完結
  - `git -C path push` / `env VAR=v git push` / `command git push` 等のラッパーに対応
  - 複合コマンド (`a && b`, `a; b`) を分解し、内部の各 git push を独立に検査
  - `bash -c 'git push origin main'` / `sh -c '...'` のサブシェルも 1 段だけ再パース

Claude Code フック仕様:
  - stdin に JSON が渡される。tool_input.command がコマンド文字列。
  - exit 2 でツール実行をブロックし、stderr の内容がユーザーに表示される。
  - exit 0 で通す。それ以外の異常時はフック自体の不具合で他ツールを止めないよう allow に倒す。
"""

from __future__ import annotations

import json
import shlex
import subprocess
import sys

PROTECTED = {"main", "master"}

# シェルの制御演算子 / 区切り。shlex.split では非クォートのこれらは独立トークンとして残るため、
# git push の引数列はここで切れる。
SHELL_BREAKS = {"&&", "||", ";", "|", "&", "(", ")", "{", "}", "\n"}

# サブシェル経由で渡されるコマンドを 1 段だけ再パースするためのシェル一覧。
SHELL_NAMES = {"bash", "sh", "zsh", "dash", "ksh"}
SHELL_C_FLAGS = {"-c", "-lc", "-cl", "-ic", "-ci"}


def allow() -> None:
    sys.exit(0)


def block(reason: str) -> None:
    print(f"block-push-to-main: {reason}", file=sys.stderr)
    sys.exit(2)


def normalize_dst(refspec: str) -> str:
    """refspec の dst (右辺) からブランチ名を抽出する。

    例:
      "main"                    -> "main"
      "+main"                   -> "main"
      "HEAD:main"               -> "main"
      ":main"                   -> "main"   (削除 push)
      "refs/heads/main"         -> "main"
      "feature:refs/heads/main" -> "main"
    """
    spec = refspec.lstrip("+")
    dst = spec.split(":", 1)[1] if ":" in spec else spec
    if dst.startswith("refs/heads/"):
        dst = dst[len("refs/heads/"):]
    return dst


def expand_shell_wrappers(tokens: list[str]) -> list[str]:
    """`bash -c 'inner'` のようなサブシェル呼び出しを 1 段だけ展開して inner の tokens に置換する。

    再帰展開は意図的にしない (深いネストは現実的でなく、誤展開のリスクの方が大きい)。
    """
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
            # `bash -c 'inner' arg0 arg1 ...` の arg0 以降は inner 内の $0/$1 として扱われ
            # コマンド本体ではないため捨ててよい。
            i = n
            continue
        out.append(t)
        i += 1
    return out


def find_push_sections(tokens: list[str]) -> list[tuple[list[str], str | None]]:
    """tokens 内の全ての `git ... push` シーケンスを抽出する。

    Returns:
        [(push_args, cwd), ...] の配列。push_args は push サブコマンド以降の引数列、
        cwd は `git -C <path>` で指定された作業ディレクトリ (なければ None)。
    """
    sections: list[tuple[list[str], str | None]] = []
    n = len(tokens)
    i = 0
    while i < n:
        if tokens[i] != "git":
            i += 1
            continue
        cwd: str | None = None
        j = i + 1
        push_at = -1
        while j < n:
            t = tokens[j]
            if t == "push":
                push_at = j
                break
            if t in SHELL_BREAKS:
                break
            if t == "-C" and j + 1 < n:
                cwd = tokens[j + 1]
                j += 2
                continue
            if t.startswith("--git-dir=") or t.startswith("--work-tree="):
                j += 1
                continue
            if t.startswith("-"):
                j += 1
                continue
            # git の直後に push 以外の non-flag (status, log 等) → 別サブコマンド
            break
        if push_at == -1:
            i = j + 1
            continue
        # push の引数を次の SHELL_BREAK まで切り出す
        k = push_at + 1
        while k < n and tokens[k] not in SHELL_BREAKS:
            k += 1
        sections.append((tokens[push_at + 1:k], cwd))
        i = k + 1 if k < n else k
    return sections


def analyze_push_args(args: list[str]) -> tuple[list[str], bool, bool, bool]:
    """git push 以降の引数を分解する。

    Returns:
        positional: positional 引数 (先頭が remote、以降が refspec)
        is_mirror, is_all, is_delete: それぞれのフラグの有無
    """
    positional: list[str] = []
    is_mirror = is_all = is_delete = False
    after_dashdash = False
    for tok in args:
        if after_dashdash:
            positional.append(tok)
            continue
        if tok == "--":
            after_dashdash = True
            continue
        if tok == "--mirror":
            is_mirror = True
        elif tok == "--all":
            is_all = True
        elif tok in ("--delete", "-d"):
            is_delete = True
        elif tok.startswith("-"):
            # その他のフラグ (--tags, --force, --no-verify など) は判定に影響しない
            continue
        else:
            positional.append(tok)
    return positional, is_mirror, is_all, is_delete


def current_branch(cwd: str | None) -> str:
    """現在ブランチを取得。失敗時は空文字 (= 保護対象でないとみなす)。"""
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            capture_output=True, text=True, timeout=5, cwd=cwd,
        )
    except Exception:
        return ""
    if result.returncode != 0:
        return ""
    return result.stdout.strip()


def evaluate_section(args: list[str], cwd: str | None) -> str | None:
    """1 つの git push セクションを評価する。block すべきなら理由文字列、許可なら None を返す。"""
    positional, is_mirror, is_all, is_delete = analyze_push_args(args)

    if is_mirror:
        return "git push --mirror は禁止 (保護 ref を含む全 ref を強制 push する)"
    if is_all:
        return "git push --all は禁止 (main/master を含む全 head が対象)"

    refspecs = positional[1:] if positional else []

    if is_delete:
        for spec in refspecs:
            if normalize_dst(spec) in PROTECTED:
                return f"git push --delete {spec} は保護ブランチの削除のため禁止"
        return None  # --delete モードでは保護以外の refspec は許可

    for spec in refspecs:
        dst = normalize_dst(spec)
        if dst in PROTECTED:
            return f"refspec '{spec}' が保護ブランチ ({dst}) を指すため禁止"

    if not refspecs:
        branch = current_branch(cwd)
        if branch in PROTECTED:
            return f"現在ブランチが {branch} のため、暗黙の push 先が保護ブランチ"

    return None


def main() -> None:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        # 入力不正なら通す (フック自体の誤検知で他ツールを止めない)
        allow()

    tool_input = payload.get("tool_input") or {}
    cmd = tool_input.get("command") or ""
    if not isinstance(cmd, str) or "git" not in cmd:
        allow()

    try:
        tokens = shlex.split(cmd, posix=True)
    except ValueError:
        # クォート閉じ忘れ等は元コマンド側で失敗するので通す
        allow()

    tokens = expand_shell_wrappers(tokens)

    sections = find_push_sections(tokens)
    if not sections:
        allow()

    for push_args, cwd in sections:
        reason = evaluate_section(push_args, cwd)
        if reason:
            block(reason)

    allow()


if __name__ == "__main__":
    main()
