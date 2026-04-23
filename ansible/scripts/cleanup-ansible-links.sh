#!/usr/bin/env bash
# Ansible が作った既存シンボリックリンクを一括で削除する
#
# 安全策:
#   - 対象パスがシンボリックリンクでない場合はスキップ
#   - リンク先が $HOME/dotfiles 配下以外なら保持 (ansible 製でない可能性が高い)
#   - リンク先が $HOME/dotfiles/home 配下なら保持 (stow 適用後のリンクは残す)
#
# 使い方:
#   ./cleanup-ansible-links.sh            # 削除
#   ./cleanup-ansible-links.sh --dry-run  # 削除せず計画だけ表示

set -euo pipefail

dry_run=0
for arg in "$@"; do
  case "$arg" in
    -n|--dry-run) dry_run=1 ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *)
      echo "unknown option: $arg" >&2
      exit 2
      ;;
  esac
done

dotfiles_root="${HOME}/dotfiles"
stow_root="${dotfiles_root}/home"

# Ansible の playbook に記述されていた dotfile 一覧 (リンク先)
targets=(
  "${HOME}/.vimrc"
  "${HOME}/.vim"
  "${HOME}/.bashrc"
  "${HOME}/.bash_profile"
  "${HOME}/.zshrc.akaimo"
  "${HOME}/.tmux.conf"
  "${HOME}/.gitconfig"
  "${HOME}/.gitignore"
  "${HOME}/.rubocop.yml"
  "${HOME}/.xvimrc"
  "${HOME}/.ideavimrc"
  "${HOME}/.finicky.js"
  "${HOME}/.npmrc"
  "${HOME}/.config/nvim"
  "${HOME}/.config/mise"
  "${HOME}/.config/ghostty"
  "${HOME}/.config/uv/uv.toml"
  "${HOME}/.claude/CLAUDE.md"
  "${HOME}/.claude/settings.json"
  "${HOME}/.claude/statusline.sh"
  "${HOME}/.claude/agents"
  "${HOME}/.claude/commands"
  "${HOME}/.claude/skills"
  "${HOME}/.claude/rules"
)

removed=0
kept=0
skipped=0
missing=0

# 相対パスのリンクを、リンク元ディレクトリ基準の絶対パスに正規化する
# 文字列マッチで誤判定しないよう、末尾で '..' '.' '//' を畳んで canonical path にする
resolve_link_target() {
  local link_path="$1"
  local target absolute
  target=$(readlink "$link_path")
  case "$target" in
    /*) absolute="$target" ;;
    *)  absolute="$(dirname "$link_path")/$target" ;;
  esac
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import os,sys; print(os.path.normpath(sys.argv[1]))' "$absolute"
  else
    printf '%s' "$absolute"
  fi
}

for path in "${targets[@]}"; do
  if [[ -L "$path" ]]; then
    resolved=$(resolve_link_target "$path")

    # $HOME/dotfiles 配下を指していないリンクは触らない
    if [[ "$resolved" != "$dotfiles_root"/* ]]; then
      echo "[keep]    $path -> $resolved (dotfiles 外のリンクは保持)"
      kept=$((kept + 1))
      continue
    fi

    # 既に stow 済み (home/ 配下) のリンクは消さない
    if [[ "$resolved" == "$stow_root"/* ]]; then
      echo "[keep]    $path -> $resolved (stow 済み)"
      kept=$((kept + 1))
      continue
    fi

    if [[ "$dry_run" -eq 1 ]]; then
      echo "[dry-rm]  $path -> $resolved"
    else
      rm -- "$path"
      echo "[removed] $path -> $resolved"
    fi
    removed=$((removed + 1))
  elif [[ -e "$path" ]]; then
    echo "[skip]    $path はシンボリックリンクではないため触らない"
    skipped=$((skipped + 1))
  else
    missing=$((missing + 1))
  fi
done

echo
if [[ "$dry_run" -eq 1 ]]; then
  echo "summary (dry-run):"
  echo "  would remove: $removed"
else
  echo "summary:"
  echo "  removed: $removed"
fi
echo "  kept:    $kept"
echo "  skipped: $skipped (実体ファイル/ディレクトリ)"
echo "  missing: $missing (対象が存在せず)"

if [[ "$dry_run" -eq 1 ]]; then
  echo
  echo "実行するには --dry-run なしで再実行してください"
fi
