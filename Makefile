.DEFAULT_GOAL := help

.PHONY: help vim brew stow stow-dry-run ansible-links-cleanup ansible-links-cleanup-dry-run karabiner-backup

help:
	@echo "Available targets:"
	@echo "  make brew                          - Brewfile からパッケージをインストール"
	@echo "  make stow                          - dotfiles のシンボリックリンクを作成"
	@echo "  make stow-dry-run                  - stow の計画を確認 (削除しない)"
	@echo "  make ansible-links-cleanup         - 旧 ansible 由来の symlink を削除"
	@echo "  make ansible-links-cleanup-dry-run - cleanup の計画を確認"
	@echo "  make vim                           - vim-plug / pynvim のセットアップ"
	@echo "  make karabiner-backup              - Karabiner 設定を karabiner/karabiner.json にコピー (git でバージョン管理用)"

vim:
	# vim-plug を vim / nvim の autoload に配置
	curl -fLo $(HOME)/.vim/autoload/plug.vim --create-dirs \
		https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
	curl -fLo $(HOME)/.local/share/nvim/site/autoload/plug.vim --create-dirs \
		https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
	# nvim 専用 venv を uv で作り、pynvim (Python provider) を入れる
	# init.vim 側で g:python3_host_prog = ~/.local/share/nvim/venv/bin/python を指す
	# --allow-existing で再実行時に venv を作り直さず中身を維持 (冪等)
	uv venv --allow-existing $(HOME)/.local/share/nvim/venv
	uv pip install --python $(HOME)/.local/share/nvim/venv/bin/python pynvim
	@echo ""
	@echo "次に vim / nvim を起動して :PlugInstall を実行してください"

brew:
	brew bundle --file=Brewfile

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

# Karabiner-Elements の設定を現在の PC からリポジトリ直下 karabiner/ にコピーする。
# stow 対象外なので symlink ではなく実ファイルとしてコピーし、差分を git で確認してコミットする運用。
# automatic_backups/ は Karabiner が日次で自動生成するため対象外。
karabiner-backup:
	@test -f $(HOME)/.config/karabiner/karabiner.json \
		|| (echo "ERROR: $(HOME)/.config/karabiner/karabiner.json が見つかりません。Karabiner-Elements がインストール & 起動済みか確認してください" && exit 1)
	mkdir -p karabiner
	cp $(HOME)/.config/karabiner/karabiner.json karabiner/karabiner.json
	@echo "karabiner/karabiner.json を更新しました。'git diff karabiner/' で差分を確認してコミットしてください"
