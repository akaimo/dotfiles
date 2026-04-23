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
