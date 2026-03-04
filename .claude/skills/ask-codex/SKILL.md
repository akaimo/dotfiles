---
name: ask-codex
description: Asks Codex CLI for coding assistance. Use for getting a second opinion, code generation, debugging, or delegating coding tasks.
allowed-tools: ["Bash(codex -a never -s read-only exec *)", "Bash(codex -a never -s read-only review *)"]
---

# Ask Codex

Codex CLI を read-only サンドボックスで実行し、セカンドオピニオンを得る。

**Note:** `codex` CLI がシステムの PATH に存在する必要がある。

## Quick start

```bash
codex -a never -s read-only exec "Your question or task here"
```

## Common options

| Option | Description |
|--------|-------------|
| `-a never` | 承認プロンプトをスキップ（必須、グローバルオプション） |
| `-s read-only` | read-only サンドボックスで実行（必須、グローバルオプション） |
| `-m MODEL` | モデルを指定 |
| `-C DIR` | 作業ディレクトリを指定（現在のリポジトリ配下に限定すること） |

> その他のオプションは `codex exec --help` を参照

## Examples

**コーディングの質問:**

```bash
codex -a never -s read-only exec "How do I implement a binary search in Python?"
```

**特定のサブディレクトリのコードを分析:**

```bash
codex -a never -s read-only exec -C ./src "Explain the architecture of this codebase"
```

**モデルを指定:**

```bash
codex -a never -s read-only exec -m gpt-5.3-codex "Write a function that validates email addresses"
```

**コードレビュー:**

```bash
codex -a never -s read-only review --uncommitted
```

```bash
codex -a never -s read-only review --base HEAD~1
```

```bash
codex -a never -s read-only review --base main
```

## セキュリティ

このスキルは**読み取り専用**で使用する。コード変更は Claude Code 側で行う。

**禁止オプション（絶対に使用しないこと）:**

- `--full-auto` — workspace-write サンドボックスで自動実行される
- `--dangerously-bypass-approvals-and-sandbox` — サンドボックスなしで実行される
- `-s workspace-write` — ファイル書き込みが可能になる
- `-s danger-full-access` — 全アクセスが可能になる

## Notes

- codexはread-onlyサンドボックスで実行する
- ファイル変更は一切行わない。分析・助言のみに使用する
- `-C` は現在の作業リポジトリ配下に限定して使用する
