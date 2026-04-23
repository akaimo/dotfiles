.DEFAULT_GOAL := help

help:
	@echo "Available targets:"
	@echo "  make brew                          - Brewfile からパッケージをインストール"
	@echo "  make stow                          - dotfiles のシンボリックリンクを作成"
	@echo "  make stow-dry-run                  - stow の計画を確認 (削除しない)"
	@echo "  make ansible-links-cleanup         - 旧 ansible 由来の symlink を削除"
	@echo "  make ansible-links-cleanup-dry-run - cleanup の計画を確認"
	@echo "  make vim                           - vim-plug / pynvim のセットアップ"

vim:
	ansible-playbook -i .inventory playbook.yaml -t vim --ask-become-pass

brew:
	brew bundle --file=../Brewfile

stow:
	# folding 防止のため ~/.config, ~/.config/uv, ~/.claude, ~/.vim を事前に実ディレクトリとして確保する
	mkdir -p $(HOME)/.config $(HOME)/.config/uv $(HOME)/.claude $(HOME)/.vim
	stow -d $(HOME)/dotfiles -t $(HOME) home

stow-dry-run:
	stow -nv -d $(HOME)/dotfiles -t $(HOME) home

ansible-links-cleanup:
	./scripts/cleanup-ansible-links.sh

ansible-links-cleanup-dry-run:
	./scripts/cleanup-ansible-links.sh --dry-run
