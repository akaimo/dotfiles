#!/usr/bin/env python3
"""audit_log.py のテスト。

実行方法:
  python3 -m unittest test_audit_log -v
  または
  python3 ~/.claude/hooks/test_audit_log.py
"""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audit_log  # noqa: E402

HOOK = os.path.join(os.path.dirname(os.path.abspath(__file__)), "audit_log.py")


# ============================ 共通基底 ============================

class _TmpDirCase(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.mkdtemp(prefix="audit-log-test-")
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)


# ============================ mask_secrets ============================

class TestMaskSecrets(unittest.TestCase):
    # --- dict キー名 ---
    def test_dict_password(self):
        self.assertEqual(audit_log.mask_secrets({"password": "x"})["password"], "***")

    def test_dict_api_key(self):
        self.assertEqual(audit_log.mask_secrets({"api_key": "abc"})["api_key"], "***")

    def test_dict_token(self):
        self.assertEqual(audit_log.mask_secrets({"access_token": "abc"})["access_token"], "***")

    def test_dict_authorization(self):
        self.assertEqual(audit_log.mask_secrets({"Authorization": "Bearer x"})["Authorization"], "***")

    def test_dict_aws_secret_access_key(self):
        self.assertEqual(audit_log.mask_secrets({"aws_secret_access_key": "x"})["aws_secret_access_key"], "***")

    def test_dict_nested(self):
        out = audit_log.mask_secrets({"a": {"secret_key": "x"}, "b": [{"token": "y"}]})
        self.assertEqual(out["a"]["secret_key"], "***")
        self.assertEqual(out["b"][0]["token"], "***")

    def test_dict_empty_value_kept(self):
        # 空文字や None はそのまま (機密ではないため)
        out = audit_log.mask_secrets({"password": ""})
        self.assertEqual(out["password"], "")

    def test_dict_immutable_does_not_mutate_input(self):
        d = {"password": "x"}
        audit_log.mask_secrets(d)
        self.assertEqual(d["password"], "x")

    # --- ヘッダ ---
    def test_authorization_bearer_full_value(self):
        s = "Authorization: Bearer abcdef123456"
        out = audit_log.mask_secrets(s)
        self.assertEqual(out, "Authorization: ***")
        self.assertNotIn("abcdef", out)

    def test_authorization_within_quoted_curl(self):
        s = "curl -H 'Authorization: Bearer xyz' https://x.com"
        out = audit_log.mask_secrets(s)
        self.assertNotIn("Bearer xyz", out)
        self.assertIn("Authorization: ***", out)

    def test_proxy_authorization(self):
        self.assertEqual(audit_log.mask_secrets("Proxy-Authorization: Basic abc=="),
                         "Proxy-Authorization: ***")

    def test_x_api_key_header(self):
        self.assertEqual(audit_log.mask_secrets("X-API-Key: super-secret-12345"),
                         "X-API-Key: ***")

    def test_x_auth_token_header(self):
        self.assertEqual(audit_log.mask_secrets("X-Auth-Token: abc123"),
                         "X-Auth-Token: ***")

    def test_cookie_header(self):
        out = audit_log.mask_secrets("Cookie: session=abc; csrf=def")
        self.assertEqual(out, "Cookie: ***")

    def test_set_cookie_header(self):
        out = audit_log.mask_secrets("Set-Cookie: session=abc; HttpOnly")
        self.assertEqual(out, "Set-Cookie: ***")

    # --- URL クレデンシャル ---
    def test_https_basic_auth(self):
        out = audit_log.mask_secrets("https://user:pass@example.com/path")
        self.assertEqual(out, "https://***:***@example.com/path")

    def test_postgres_url(self):
        out = audit_log.mask_secrets("postgres://admin:hunter2@db:5432/x")
        self.assertIn("***:***@", out)

    def test_redis_url(self):
        out = audit_log.mask_secrets("redis://x:secretpw@host:6379")
        self.assertIn("***:***@", out)

    # --- query string ---
    def test_query_token(self):
        out = audit_log.mask_secrets("https://x/?token=abcdef&z=1")
        self.assertIn("?token=***", out)
        self.assertIn("z=1", out)

    def test_query_access_token(self):
        out = audit_log.mask_secrets("https://x/?access_token=AAA&y=2")
        self.assertIn("access_token=***", out)

    def test_query_client_secret(self):
        out = audit_log.mask_secrets("https://x/?client_secret=XYZ")
        self.assertIn("client_secret=***", out)

    # --- トークン形式 ---
    def test_jwt(self):
        jwt = ("eyJhbGciOiJIUzI1NiJ9."
               "eyJzdWIiOiIxMjM0NTY3ODkwIn0."
               "SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c")
        self.assertEqual(audit_log.mask_secrets(jwt), "***JWT***")

    def test_aws_akia(self):
        self.assertEqual(audit_log.mask_secrets("AKIAIOSFODNN7EXAMPLE"), "***AWSKEY***")

    def test_aws_asia(self):
        self.assertEqual(audit_log.mask_secrets("ASIAIOSFODNN7EXAMPLE"), "***AWSKEY***")

    def test_openai_sk(self):
        self.assertEqual(audit_log.mask_secrets("sk-abcdefghij1234567890XYZ"), "***")

    def test_openai_sk_proj(self):
        self.assertEqual(audit_log.mask_secrets("sk-proj-abcdefghij1234567890XYZ"), "***")

    def test_anthropic_sk_ant(self):
        self.assertEqual(audit_log.mask_secrets("sk-ant-api03-abcdefghij1234567890XYZ"), "***")

    def test_github_ghp(self):
        self.assertEqual(audit_log.mask_secrets("ghp_abcdefghij1234567890XYZ"), "***")

    def test_github_pat(self):
        out = audit_log.mask_secrets("github_pat_abcdefghij1234567890_extramore")
        self.assertEqual(out, "***")

    def test_gitlab_glpat(self):
        self.assertEqual(audit_log.mask_secrets("glpat-abcdefghij1234567890"), "***")

    def test_slack_xoxb(self):
        self.assertEqual(audit_log.mask_secrets("xoxb-1234567890-abcdef"), "***")

    def test_npm_token(self):
        s = "npm_" + "a" * 36
        self.assertEqual(audit_log.mask_secrets(s), "***")

    def test_google_api_key(self):
        s = "AIza" + "a" * 35
        self.assertEqual(audit_log.mask_secrets(s), "***")

    def test_stripe_live(self):
        self.assertEqual(audit_log.mask_secrets("sk_live_abcdefghij1234567890"), "***")

    def test_stripe_test(self):
        self.assertEqual(audit_log.mask_secrets("rk_test_abcdefghij1234567890"), "***")

    def test_pem_block(self):
        pem = ("-----BEGIN RSA PRIVATE KEY-----\n"
               "MIIEpAIBAAKCAQEAfakebase64data\n"
               "-----END RSA PRIVATE KEY-----")
        out = audit_log.mask_secrets(pem)
        self.assertIn("***PEM***", out)
        self.assertNotIn("MIIEpAIBAAKCAQ", out)

    def test_netrc(self):
        out = audit_log.mask_secrets("machine api.github.com login user password supersecret")
        self.assertIn("login ***", out)
        self.assertIn("password ***", out)
        self.assertNotIn("supersecret", out)

    def test_env_var_assignment(self):
        out = audit_log.mask_secrets("export API_TOKEN=abc123def456")
        self.assertIn("API_TOKEN=***", out)
        self.assertNotIn("abc123def456", out)

    def test_safe_string_passthrough(self):
        self.assertEqual(audit_log.mask_secrets("hello world"), "hello world")

    def test_url_without_credentials_passthrough(self):
        s = "https://example.com/path?q=hello"
        self.assertEqual(audit_log.mask_secrets(s), s)

    # --- 過剰マスク防止 (codex minor 指摘) ---
    def test_dict_author_not_masked(self):
        out = audit_log.mask_secrets({"author": "alice"})
        self.assertEqual(out["author"], "alice")

    def test_dict_max_tokens_not_masked(self):
        out = audit_log.mask_secrets({"max_tokens": 1024})
        self.assertEqual(out["max_tokens"], 1024)

    def test_dict_token_count_not_masked(self):
        out = audit_log.mask_secrets({"token_count": 42})
        self.assertEqual(out["token_count"], 42)

    def test_dict_input_tokens_not_masked(self):
        out = audit_log.mask_secrets({"input_tokens": 100, "output_tokens": 200})
        self.assertEqual(out["input_tokens"], 100)
        self.assertEqual(out["output_tokens"], 200)

    def test_dict_access_token_still_masked(self):
        out = audit_log.mask_secrets({"access_token": "abc"})
        self.assertEqual(out["access_token"], "***")

    # --- 空白入り quoted env 値 ---
    def test_env_quoted_double(self):
        out = audit_log.mask_secrets('export PASSWORD="abc def ghi"')
        self.assertNotIn("abc def", out)
        self.assertIn("PASSWORD=***", out)

    def test_env_quoted_single(self):
        out = audit_log.mask_secrets("API_KEY='space here xxx'")
        self.assertNotIn("space here", out)
        self.assertIn("API_KEY=***", out)


# ============================ external access ============================

class TestExternalAccess(unittest.TestCase):
    def _check(self, tool_name, tool_input, expected, label=""):
        ext, reason = audit_log.is_external_access(tool_name, tool_input)
        self.assertEqual(ext, expected,
                         f"{label}: tool={tool_name} input={tool_input} got={ext} reason={reason}")
        return reason

    # tool ベース
    def test_webfetch(self):
        self._check("WebFetch", {"url": "https://x.com"}, True)

    def test_websearch(self):
        self._check("WebSearch", {"query": "python"}, True)

    def test_mcp(self):
        self._check("mcp__server__do_thing", {}, True)

    def test_read_local(self):
        self._check("Read", {"file_path": "/etc/hosts"}, False)

    def test_edit_local(self):
        self._check("Edit", {"file_path": "/tmp/x"}, False)

    def test_write_local(self):
        self._check("Write", {"file_path": "/tmp/x"}, False)

    # Bash 単純コマンド
    def test_bash_curl(self):
        self._check("Bash", {"command": "curl https://x.com"}, True)

    def test_bash_wget(self):
        self._check("Bash", {"command": "wget https://x.com/file"}, True)

    def test_bash_nc(self):
        self._check("Bash", {"command": "nc example.com 80"}, True)

    def test_bash_ssh(self):
        self._check("Bash", {"command": "ssh user@host"}, True)

    def test_bash_scp(self):
        self._check("Bash", {"command": "scp file user@host:/tmp"}, True)

    def test_bash_rsync(self):
        self._check("Bash", {"command": "rsync -av src/ user@host:/dst"}, True)

    def test_bash_dig(self):
        self._check("Bash", {"command": "dig example.com"}, True)

    def test_bash_nslookup(self):
        self._check("Bash", {"command": "nslookup example.com"}, True)

    def test_bash_ping(self):
        self._check("Bash", {"command": "ping -c 3 example.com"}, True)

    def test_bash_socat(self):
        self._check("Bash", {"command": "socat - TCP:example.com:80"}, True)

    # Bash サブコマンド
    def test_bash_git_push(self):
        self._check("Bash", {"command": "git push origin feature"}, True)

    def test_bash_git_fetch(self):
        self._check("Bash", {"command": "git fetch origin"}, True)

    def test_bash_git_clone(self):
        self._check("Bash", {"command": "git clone https://github.com/x/y.git"}, True)

    def test_bash_git_pull(self):
        self._check("Bash", {"command": "git pull --rebase"}, True)

    def test_bash_git_ls_remote(self):
        self._check("Bash", {"command": "git ls-remote origin"}, True)

    def test_bash_npm_install(self):
        self._check("Bash", {"command": "npm install lodash"}, True)

    def test_bash_pip_install(self):
        self._check("Bash", {"command": "pip install requests"}, True)

    def test_bash_docker_pull(self):
        self._check("Bash", {"command": "docker pull alpine"}, True)

    def test_bash_brew_install(self):
        self._check("Bash", {"command": "brew install jq"}, True)

    # Bash CLI ツール
    def test_bash_gh_api(self):
        self._check("Bash", {"command": "gh api repos/octocat/hello-world"}, True)

    def test_bash_aws_s3(self):
        self._check("Bash", {"command": "aws s3 ls"}, True)

    def test_bash_kubectl(self):
        self._check("Bash", {"command": "kubectl get pods"}, True)

    # スクリプト経由
    def test_bash_python_inline_requests(self):
        self._check("Bash",
                    {"command": "python -c 'import requests; requests.get(\"https://x.com\")'"},
                    True)

    def test_bash_node_inline_fetch(self):
        self._check("Bash", {"command": "node -e 'fetch(\"https://x.com\")'"}, True)

    # /dev/tcp
    def test_bash_dev_tcp(self):
        self._check("Bash", {"command": "exec 3<>/dev/tcp/example.com/80"}, True)

    # URL リテラル単体は外部アクセスとは判定しない (false positive 防止)
    def test_bash_url_literal_in_echo_is_local(self):
        self._check("Bash", {"command": "echo https://example.com"}, False)

    def test_bash_url_literal_in_grep_is_local(self):
        self._check("Bash", {"command": "grep 'https://x.com' file.txt"}, False)

    # wrapper option 付き curl も検出
    def test_bash_env_with_flag_curl(self):
        self._check("Bash", {"command": "env -i curl https://x.com"}, True)

    def test_bash_sudo_user_curl(self):
        self._check("Bash", {"command": "sudo -u nobody curl https://x.com"}, True)

    def test_bash_time_curl(self):
        self._check("Bash", {"command": "time -p curl https://x.com"}, True)

    # ローカル操作
    def test_bash_ls(self):
        self._check("Bash", {"command": "ls -la"}, False)

    def test_bash_echo(self):
        self._check("Bash", {"command": "echo hello"}, False)

    def test_bash_git_status(self):
        self._check("Bash", {"command": "git status"}, False)

    def test_bash_git_log(self):
        self._check("Bash", {"command": "git log --oneline"}, False)

    def test_bash_git_diff(self):
        self._check("Bash", {"command": "git diff HEAD~1"}, False)

    # サブシェル展開
    def test_bash_subshell_curl(self):
        self._check("Bash", {"command": "bash -c 'curl https://x.com'"}, True)

    def test_bash_subshell_safe(self):
        self._check("Bash", {"command": "bash -c 'ls -la'"}, False)


# ============================ targets 抽出 ============================

class TestExtractTargets(unittest.TestCase):
    def test_webfetch_url(self):
        targets = audit_log.extract_external_targets(
            "WebFetch", {"url": "https://api.example.com:8443/path"})
        self.assertEqual(len(targets), 1)
        self.assertEqual(targets[0]["host"], "api.example.com")
        self.assertEqual(targets[0]["port"], 8443)
        self.assertEqual(targets[0]["scheme"], "https")

    def test_webfetch_default_https_port(self):
        targets = audit_log.extract_external_targets("WebFetch", {"url": "https://example.com/a"})
        self.assertEqual(targets[0]["port"], 443)

    def test_webfetch_default_http_port(self):
        targets = audit_log.extract_external_targets("WebFetch", {"url": "http://example.com"})
        self.assertEqual(targets[0]["port"], 80)

    def test_mcp_target(self):
        targets = audit_log.extract_external_targets("mcp__foo__bar", {})
        self.assertEqual(targets, [{"type": "mcp", "tool": "mcp__foo__bar"}])

    def test_bash_url_extract(self):
        targets = audit_log.extract_external_targets(
            "Bash", {"command": "curl -X POST https://api.example.com:8080/x"})
        self.assertTrue(any(t.get("host") == "api.example.com" and t.get("port") == 8080
                            for t in targets))

    def test_bash_git_remote_origin(self):
        targets = audit_log.extract_external_targets(
            "Bash", {"command": "git push origin feature"})
        self.assertTrue(any(t.get("type") == "git_remote" and t.get("remote") == "origin"
                            for t in targets))

    def test_bash_git_clone_url(self):
        targets = audit_log.extract_external_targets(
            "Bash", {"command": "git clone https://github.com/octocat/hello.git"})
        # URL 抽出と git_remote 抽出が両方できる
        hosts = [t.get("host") for t in targets if "host" in t]
        remotes = [t.get("remote") for t in targets if t.get("type") == "git_remote"]
        self.assertIn("github.com", hosts)
        self.assertTrue(any(r and "github.com" in r for r in remotes))


# ============================ summarize_response ============================

class TestSummarize(unittest.TestCase):
    def test_string(self):
        s = audit_log.summarize_response("hello")
        self.assertEqual(s["bytes"], 5)
        self.assertEqual(s["lines"], 1)
        self.assertEqual(len(s["sha256"]), 64)

    def test_dict(self):
        s = audit_log.summarize_response({"a": 1})
        self.assertGreater(s["bytes"], 0)

    def test_none(self):
        self.assertEqual(audit_log.summarize_response(None),
                         {"sha256": "", "bytes": 0, "lines": 0})

    def test_no_snippet_field(self):
        s = audit_log.summarize_response("Authorization: Bearer secret123")
        self.assertNotIn("snippet", s)
        self.assertNotIn("preview", s)
        for v in s.values():
            self.assertNotIn("Bearer", str(v))
            self.assertNotIn("secret123", str(v))

    def test_multiline(self):
        s = audit_log.summarize_response("a\nb\nc")
        self.assertEqual(s["lines"], 3)


# ============================ build_record ============================

class TestBuildRecord(unittest.TestCase):
    def _common(self, payload):
        rec = audit_log.build_record(payload)
        for f in ("ts", "event", "session_id", "user", "uid", "hostname", "pid", "ppid"):
            self.assertIn(f, rec, f"missing common field: {f}")
        return rec

    def test_pretooluse_local(self):
        rec = self._common({
            "hook_event_name": "PreToolUse", "session_id": "s1", "cwd": "/tmp",
            "tool_name": "Bash", "tool_input": {"command": "ls"},
        })
        self.assertEqual(rec["event"], "PreToolUse")
        self.assertFalse(rec["external_access"])

    def test_pretooluse_external_with_targets(self):
        rec = audit_log.build_record({
            "hook_event_name": "PreToolUse",
            "tool_name": "Bash",
            "tool_input": {"command": "curl https://api.example.com:8080/x"},
        })
        self.assertTrue(rec["external_access"])
        self.assertIn("external_reason", rec)
        self.assertIn("external_targets", rec)
        self.assertTrue(any(t.get("host") == "api.example.com" for t in rec["external_targets"]))

    def test_pretooluse_masks_authorization(self):
        rec = audit_log.build_record({
            "hook_event_name": "PreToolUse",
            "tool_name": "Bash",
            "tool_input": {"command": "curl -H 'Authorization: Bearer xyz' https://x.com"},
        })
        cmd = rec["tool_input"]["command"]
        self.assertNotIn("Bearer xyz", cmd)
        self.assertIn("Authorization: ***", cmd)

    def test_posttooluse_no_snippet(self):
        rec = audit_log.build_record({
            "hook_event_name": "PostToolUse",
            "tool_name": "Bash", "tool_input": {"command": "cat /etc/hosts"},
            "tool_response": "127.0.0.1 localhost\nAuthorization: Bearer secret",
        })
        self.assertEqual(rec["event"], "PostToolUse")
        # スニペット非保存
        self.assertNotIn("snippet", rec["tool_response"])
        for v in rec["tool_response"].values():
            self.assertNotIn("Bearer secret", str(v))

    def test_userpromptsubmit(self):
        rec = audit_log.build_record({
            "hook_event_name": "UserPromptSubmit", "prompt": "hello world",
        })
        self.assertEqual(rec["prompt"], "hello world")

    def test_userpromptsubmit_masks(self):
        rec = audit_log.build_record({
            "hook_event_name": "UserPromptSubmit",
            "prompt": "set TOKEN: ghp_abcdefghij1234567890",
        })
        self.assertNotIn("ghp_abcdefghij1234567890", rec["prompt"])
        self.assertIn("***", rec["prompt"])

    def test_session_start(self):
        rec = audit_log.build_record({"hook_event_name": "SessionStart", "source": "startup"})
        self.assertEqual(rec["source"], "startup")

    def test_session_end(self):
        rec = audit_log.build_record({"hook_event_name": "SessionEnd", "reason": "user_exit"})
        self.assertEqual(rec["reason"], "user_exit")

    def test_stop(self):
        rec = audit_log.build_record({"hook_event_name": "Stop", "stop_hook_active": True})
        self.assertTrue(rec["stop_hook_active"])

    def test_unknown_event_keeps_common_fields(self):
        rec = audit_log.build_record({"hook_event_name": "FuturisticEvent"})
        self.assertEqual(rec["event"], "FuturisticEvent")


# ============================ truncate ============================

class TestTruncate(unittest.TestCase):
    def test_under_limit_unchanged(self):
        rec = {"event": "PreToolUse", "tool_input": {"command": "ls"}}
        out = audit_log.truncate_if_oversized(dict(rec))
        self.assertEqual(out["tool_input"], {"command": "ls"})

    def test_over_limit_truncates_tool_input(self):
        big = "A" * (40 * 1024)
        rec = {"event": "PreToolUse", "tool_input": {"command": big}}
        out = audit_log.truncate_if_oversized(rec)
        self.assertTrue(out["tool_input"].get("_truncated"))
        self.assertIn("sha256", out["tool_input"])
        self.assertEqual(len(out["tool_input"]["sha256"]), 64)

    def test_over_limit_truncates_prompt(self):
        big = "P" * (40 * 1024)
        rec = {"event": "UserPromptSubmit", "prompt": big}
        out = audit_log.truncate_if_oversized(rec)
        self.assertTrue(out["prompt"].get("_truncated"))
        self.assertIn("sha256", out["prompt"])

    def test_over_limit_truncates_custom_instructions(self):
        big = "C" * (40 * 1024)
        rec = {"event": "PreCompact", "custom_instructions": big}
        out = audit_log.truncate_if_oversized(rec)
        self.assertTrue(out["custom_instructions"].get("_truncated"))


# ============================ write_record / hash chain ============================

class TestWriteRecord(_TmpDirCase):
    def _read_log(self):
        files = list(Path(self.tmp).glob("*.jsonl"))
        self.assertEqual(len(files), 1, f"expected 1 log file, got {len(files)}: {files}")
        with open(files[0]) as f:
            return [json.loads(l) for l in f if l.strip()]

    def test_creates_file_with_600(self):
        rec = audit_log.build_record({
            "hook_event_name": "PreToolUse",
            "tool_name": "Bash", "tool_input": {"command": "ls"},
        })
        audit_log.write_record(rec, log_dir=self.tmp)
        files = list(Path(self.tmp).glob("*.jsonl"))
        self.assertEqual(len(files), 1)
        mode = files[0].stat().st_mode & 0o777
        self.assertEqual(mode, 0o600, f"expected 0o600, got {oct(mode)}")

    def test_dir_700(self):
        rec = audit_log.build_record({"hook_event_name": "SessionStart"})
        audit_log.write_record(rec, log_dir=self.tmp)
        mode = Path(self.tmp).stat().st_mode & 0o777
        self.assertEqual(mode, 0o700, f"expected 0o700, got {oct(mode)}")

    def test_filename_is_today_utc(self):
        rec = audit_log.build_record({"hook_event_name": "SessionStart"})
        audit_log.write_record(rec, log_dir=self.tmp)
        today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        self.assertTrue((Path(self.tmp) / f"{today}.jsonl").exists())

    def test_hash_chain_three_records(self):
        for i in range(3):
            rec = audit_log.build_record({
                "hook_event_name": "PreToolUse",
                "tool_name": "Bash", "tool_input": {"command": f"echo {i}"},
            })
            audit_log.write_record(rec, log_dir=self.tmp)
        records = self._read_log()
        self.assertEqual(len(records), 3)
        self.assertEqual(records[0]["prev_hash"], "0" * 64)
        self.assertEqual(records[1]["prev_hash"], records[0]["rec_hash"])
        self.assertEqual(records[2]["prev_hash"], records[1]["rec_hash"])

    def test_rec_hash_is_canonical(self):
        rec = audit_log.build_record({
            "hook_event_name": "PreToolUse",
            "tool_name": "Bash", "tool_input": {"command": "ls"},
        })
        audit_log.write_record(rec, log_dir=self.tmp)
        r = self._read_log()[0]
        body = {k: v for k, v in r.items() if k != "rec_hash"}
        s = json.dumps(body, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
        expected = hashlib.sha256(s.encode("utf-8")).hexdigest()
        self.assertEqual(r["rec_hash"], expected)

    def test_hash_chain_over_16kb_record(self):
        """最終行が 16KB を超える場合でも chain 切れにならないこと (codex 指摘 major #1)。"""
        # 1 個目: 大きめのレコードを書く (32KB 制限の縮退ロジックを通る程度に)
        big_input = {"command": "X" * (28 * 1024)}
        rec1 = audit_log.build_record({
            "hook_event_name": "PreToolUse",
            "tool_name": "Bash", "tool_input": big_input,
        })
        audit_log.write_record(rec1, log_dir=self.tmp)
        # 2 個目: 小さいレコードを書く
        rec2 = audit_log.build_record({
            "hook_event_name": "PreToolUse",
            "tool_name": "Bash", "tool_input": {"command": "ls"},
        })
        audit_log.write_record(rec2, log_dir=self.tmp)
        records = self._read_log()
        self.assertEqual(len(records), 2)
        # chain が壊れていないこと (BROKEN_CHAIN ではなく前のレコードの rec_hash と一致)
        self.assertEqual(records[1]["prev_hash"], records[0]["rec_hash"])
        self.assertNotEqual(records[1]["prev_hash"], "BROKEN_CHAIN")

    def test_existing_file_mode_normalized(self):
        """既存ファイルが 0o644 でも書き込み後 0o600 に正規化される。"""
        from datetime import datetime as _dt, timezone as _tz
        today = _dt.now(_tz.utc).strftime("%Y-%m-%d")
        path = Path(self.tmp) / f"{today}.jsonl"
        path.write_text("")
        os.chmod(path, 0o644)
        rec = audit_log.build_record({"hook_event_name": "SessionStart"})
        audit_log.write_record(rec, log_dir=self.tmp)
        mode = path.stat().st_mode & 0o777
        self.assertEqual(mode, 0o600, f"expected 0o600, got {oct(mode)}")

    def test_symlink_rejected(self):
        today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        target = os.path.join(self.tmp, "_real_target.txt")
        Path(target).write_text("")
        link = os.path.join(self.tmp, f"{today}.jsonl")
        os.symlink(target, link)
        rec = audit_log.build_record({"hook_event_name": "SessionStart"})
        with self.assertRaises(OSError):
            audit_log.write_record(rec, log_dir=self.tmp)
        # 攻撃対象ファイルが書き換わっていないこと
        self.assertEqual(Path(target).read_text(), "")


# ============================ main / フォールスルー ============================

class TestMainFallthrough(_TmpDirCase):
    def _run(self, payload, env_extra=None):
        env = {**os.environ, "AUDIT_LOG_DIR": self.tmp}
        if env_extra:
            env.update(env_extra)
        # 入力が文字列なら raw、dict なら JSON 化
        body = payload if isinstance(payload, str) else json.dumps(payload)
        return subprocess.run(
            [sys.executable, HOOK],
            input=body, capture_output=True, text=True, env=env,
        )

    def _read_log(self):
        files = list(Path(self.tmp).glob("*.jsonl"))
        if not files:
            return []
        with open(files[0]) as f:
            return [json.loads(l) for l in f if l.strip()]

    def test_invalid_json_exits_0(self):
        proc = self._run("not-json")
        self.assertEqual(proc.returncode, 0)

    def test_empty_stdin_exits_0(self):
        proc = self._run("")
        self.assertEqual(proc.returncode, 0)

    def test_pretooluse_records_event(self):
        proc = self._run({
            "hook_event_name": "PreToolUse",
            "session_id": "abc", "cwd": "/tmp",
            "tool_name": "Bash", "tool_input": {"command": "echo hi"},
        })
        self.assertEqual(proc.returncode, 0)
        records = self._read_log()
        self.assertEqual(len(records), 1)
        self.assertEqual(records[0]["event"], "PreToolUse")
        self.assertEqual(records[0]["session_id"], "abc")

    def _make_unwriteable_log_dir(self) -> str:
        """書き込み不能な log_dir パスを返す。

        親ディレクトリを 0o500 にし、その配下の存在しないサブディレクトリを log_dir として渡すことで、
        os.makedirs の作成失敗を確定させる (所有者が自分でも親が書き込み不可なら作成できない)。
        """
        parent = os.path.join(self.tmp, "ro_parent")
        os.makedirs(parent)
        os.chmod(parent, 0o500)
        self.addCleanup(os.chmod, parent, 0o700)
        return os.path.join(parent, "inside")

    def test_strict_blocks_external_on_write_failure(self):
        bad = self._make_unwriteable_log_dir()
        proc = self._run(
            {
                "hook_event_name": "PreToolUse",
                "tool_name": "Bash",
                "tool_input": {"command": "curl https://x.com"},
            },
            env_extra={"AUDIT_LOG_DIR": bad, "AUDIT_LOG_STRICT": "1"},
        )
        self.assertEqual(proc.returncode, 2,
                         f"expected exit 2, got {proc.returncode}; stderr={proc.stderr}")

    def test_strict_allows_internal_event_on_write_failure(self):
        bad = self._make_unwriteable_log_dir()
        proc = self._run(
            {
                "hook_event_name": "PreToolUse",
                "tool_name": "Bash",
                "tool_input": {"command": "ls"},
            },
            env_extra={"AUDIT_LOG_DIR": bad, "AUDIT_LOG_STRICT": "1"},
        )
        # external_access=false なら strict でも block しない
        self.assertEqual(proc.returncode, 0)


# ============================ 並行書き込み ============================

class TestConcurrent(_TmpDirCase):
    def test_concurrent_writes_chain_intact(self):
        """30 プロセスを Popen で並列起動し、flock で直列化されて chain が壊れないことを確認。"""
        n = 30
        env = {**os.environ, "AUDIT_LOG_DIR": self.tmp}
        procs = []
        # 全プロセスを spawn してから一斉に stdin を流し込む。
        for i in range(n):
            p = subprocess.Popen(
                [sys.executable, HOOK],
                stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                env=env, text=True,
            )
            procs.append((p, i))
        outs = []
        for p, i in procs:
            out, err = p.communicate(input=json.dumps({
                "hook_event_name": "PreToolUse",
                "session_id": f"s{i}", "cwd": "/tmp",
                "tool_name": "Bash", "tool_input": {"command": f"echo {i}"},
            }))
            outs.append((p.returncode, err))
        self.assertTrue(all(r == 0 for r, _ in outs),
                        f"non-zero exits: {[(r, e[:80]) for r, e in outs if r != 0]}")
        files = list(Path(self.tmp).glob("*.jsonl"))
        self.assertEqual(len(files), 1)
        with open(files[0]) as f:
            records = [json.loads(l) for l in f if l.strip()]
        self.assertEqual(len(records), n)
        prev = "0" * 64
        for i, r in enumerate(records):
            self.assertEqual(r["prev_hash"], prev,
                             f"chain broken at i={i}: prev={prev[:8]}, got={r['prev_hash'][:8]}")
            prev = r["rec_hash"]


if __name__ == "__main__":
    unittest.main(verbosity=2)
