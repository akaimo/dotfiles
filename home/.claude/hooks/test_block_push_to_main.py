#!/usr/bin/env python3
"""block-push-to-main.py のテスト。

実行方法:
  python3 ~/.claude/hooks/test_block_push_to_main.py

期待値は exit code (0 = allow, 2 = block)。
すべてのケースが「refspec が明示されている」または「git push を含まない」ものに限定されており、
現在ブランチや git 設定に依存せず再現可能。
"""

from __future__ import annotations

import json
import os
import subprocess
import sys

HOOK = os.path.join(os.path.dirname(os.path.abspath(__file__)), "block-push-to-main.py")

# (command, expected_exit, label)
CASES: list[tuple[str, int, str]] = [
    # --- 非 push / 通常 push ---
    ("ls -la", 0, "non-git"),
    ("git status", 0, "git non-push"),
    ("git push origin feature/foo", 0, "feature push"),
    ("git push origin feature/main-fix", 0, "branch contains 'main' but not target (旧 \\b 誤検知)"),
    ("git push origin user/master-thesis", 0, "branch contains 'master' but not target"),

    # --- 直接ブロック対象 ---
    ("git push origin main", 2, "explicit main"),
    ("git push origin master", 2, "explicit master"),
    ("git push origin HEAD:main", 2, "HEAD:main"),
    ("git push origin :main", 2, "delete via colon refspec"),
    ("git push origin --delete main", 2, "delete via flag"),
    ("git push origin refs/heads/main", 2, "full ref path"),
    ("git push origin +main", 2, "force prefix"),
    ("git push origin feature:refs/heads/main", 2, "src:dst with main as dst"),
    ("git push -u origin main", 2, "set upstream to main"),

    # --- フラグ ---
    ("git push --mirror origin", 2, "mirror"),
    ("git push --all origin", 2, "all"),
    ("git push --tags origin v1.0", 0, "tags with explicit tag refspec"),
    ("git push --force-with-lease origin feature/foo", 0, "long flag, safe ref"),
    ("git push --force-with-lease origin main", 2, "long flag, main"),
    ("git push --no-verify origin feature/foo", 0, "no-verify on safe ref"),
    ("git push origin --delete feature/foo", 0, "delete non-protected"),

    # --- ラッパー ---
    ("git -C /tmp push origin feature/foo", 0, "git -C path"),
    ("env GIT_TRACE=1 git push origin main", 2, "env wrapper"),
    ("command git push origin main", 2, "command wrapper"),
    ("cd push && ls", 0, "false positive: 'push' as dirname"),

    # --- 複数 push (codex 指摘 2) ---
    ("git push origin feature && git push origin main", 2, "[multi] safe then main"),
    ("git push origin main && git push origin feature", 2, "[multi] main then safe"),
    ("git push origin feature/a && git push origin feature/b", 0, "[multi] two safe pushes"),
    ("git push origin feature; git push origin main", 2, "[multi] semicolon, second is main"),
    ("git status; git push origin main", 2, "[multi] non-push then main"),
    ("git push origin feature || git push origin main", 2, "[multi] || with main fallback"),
    ("git push origin feature | tee log.txt", 0, "[multi] pipe to tee, safe"),
    ("git push origin feature && git status", 0, "[multi] safe push then status"),
    ("git status && git push origin main", 2, "[multi] status && main"),

    # --- サブシェル (codex 指摘 3) ---
    ("bash -c 'git push origin main'", 2, "[shell] bash -c main"),
    ("sh -c 'git push origin main'", 2, "[shell] sh -c main"),
    ("zsh -c 'git push origin main'", 2, "[shell] zsh -c main"),
    ("bash -lc 'git push origin main'", 2, "[shell] bash -lc main"),
    ("bash -c 'git push origin feature/foo'", 0, "[shell] bash -c feature"),
    ("bash -c \"git push origin HEAD:main\"", 2, "[shell] bash -c with HEAD:main"),
]


def run_case(cmd: str, expected: int, label: str) -> bool:
    payload = json.dumps({"tool_input": {"command": cmd}})
    proc = subprocess.run(
        [sys.executable, HOOK],
        input=payload, capture_output=True, text=True,
    )
    actual = proc.returncode
    ok = actual == expected
    if ok:
        print(f"OK  [{label}] exit={actual} :: {cmd}")
    else:
        print(f"NG  [{label}] expected={expected} actual={actual}")
        print(f"     cmd: {cmd}")
        if proc.stderr:
            print(f"     stderr: {proc.stderr.strip()}")
    return ok


def main() -> None:
    if not os.path.isfile(HOOK):
        print(f"hook not found: {HOOK}", file=sys.stderr)
        sys.exit(1)
    failed = sum(0 if run_case(*c) else 1 for c in CASES)
    total = len(CASES)
    verdict = "PASS" if failed == 0 else "FAIL"
    print(f"\n{verdict}: {total - failed}/{total}")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
