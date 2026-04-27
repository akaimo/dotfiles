.DEFAULT_GOAL := help

.PHONY: help vim brew stow stow-dry-run ansible-links-cleanup ansible-links-cleanup-dry-run karabiner-backup finicky-install

help:
	@echo "Available targets:"
	@echo "  make brew                          - Brewfile からパッケージをインストール"
	@echo "  make stow                          - dotfiles のシンボリックリンクを作成"
	@echo "  make stow-dry-run                  - stow の計画を確認 (削除しない)"
	@echo "  make ansible-links-cleanup         - 旧 ansible 由来の symlink を削除"
	@echo "  make ansible-links-cleanup-dry-run - cleanup の計画を確認"
	@echo "  make vim                           - vim-plug / pynvim のセットアップ"
	@echo "  make karabiner-backup              - Karabiner 設定を ~/.config/karabiner/ から karabiner/ に取り込む (アプリ→repo, バックアップ)"
	@echo "  make finicky-install               - finicky 設定を finicky/ から ~/.config/finicky/ に配置して再起動 (repo→アプリ, デプロイ)"

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

# finicky 設定をリポジトリ内の finicky/finicky.js から ~/.config/finicky/finicky.js にコピー配置する。
# stow による symlink にすると、git checkout / restore / pull で実体ファイルが
# 置換 (delete→create) された際に finicky の watcher (fsnotify) が Remove イベントで
# 死に、以降設定が読み込まれなくなる (v4.2.2 時点で再 watch のリトライなし)。
# よって watch 対象を git 操作の影響を受けない場所に「コピー」で配置することで
# 設定喪失問題を根本から防ぐ。
FINICKY_SRC  := finicky/finicky.js
FINICKY_DEST := $(HOME)/.config/finicky/finicky.js
# 旧 stow 由来の symlink ~/.finicky.js が指していた相対パス。これと一致する場合のみ自動削除する。
FINICKY_OLD_LINK_TARGET := dotfiles/home/.finicky.js

finicky-install:
	@test -f "$(FINICKY_SRC)" \
		|| (echo "ERROR: $(FINICKY_SRC) が見つかりません" && exit 1)
	# 配置先が symlink/ディレクトリだと cp が意図しない場所を上書きし対策が崩れるため停止する。
	@if [ -L "$(FINICKY_DEST)" ]; then \
		echo "ERROR: $(FINICKY_DEST) が symlink です。手動で退避してから再実行してください" && exit 1; \
	elif [ -d "$(FINICKY_DEST)" ]; then \
		echo "ERROR: $(FINICKY_DEST) がディレクトリです。手動で退避してから再実行してください" && exit 1; \
	fi
	# finicky の探索順では ~/.finicky.js が ~/.config/finicky/finicky.js より優先するため、確実に排除する。
	# 既知 (dotfiles の home/.finicky.js を指す) symlink のみ自動削除し、それ以外は誤削除を避けるため停止する。
	@if [ -L "$(HOME)/.finicky.js" ]; then \
		target=$$(readlink "$(HOME)/.finicky.js"); \
		if [ "$$target" = "$(FINICKY_OLD_LINK_TARGET)" ]; then \
			echo "旧 symlink を削除: $(HOME)/.finicky.js -> $$target"; \
			rm "$(HOME)/.finicky.js"; \
		else \
			echo "ERROR: $(HOME)/.finicky.js は既知でない symlink です (-> $$target)。手動で退避してから再実行してください" && exit 1; \
		fi; \
	elif [ -e "$(HOME)/.finicky.js" ]; then \
		echo "ERROR: $(HOME)/.finicky.js が実ファイル/ディレクトリです。手動で退避してから再実行してください" && exit 1; \
	fi
	mkdir -p "$(dir $(FINICKY_DEST))"
	cp "$(FINICKY_SRC)" "$(FINICKY_DEST)"
	@echo "配置完了: $(FINICKY_DEST)"
	# Finicky を再起動する。killall -w で終了を待ってから open し、起動 race を回避する。
	# 未起動時に killall は失敗するため "-" で無視する。
	-killall -w Finicky 2>/dev/null
	open -a Finicky
	@echo "Finicky を再起動しました"

# Karabiner-Elements の設定を現在の PC からリポジトリ直下 karabiner/ にコピーする。
# stow 対象外なので symlink ではなく実ファイルとしてコピーし、差分を git で確認してコミットする運用。
# automatic_backups/ は Karabiner が日次で自動生成するため対象外。
karabiner-backup:
	@test -f $(HOME)/.config/karabiner/karabiner.json \
		|| (echo "ERROR: $(HOME)/.config/karabiner/karabiner.json が見つかりません。Karabiner-Elements がインストール & 起動済みか確認してください" && exit 1)
	mkdir -p karabiner
	cp $(HOME)/.config/karabiner/karabiner.json karabiner/karabiner.json
	@echo "karabiner/karabiner.json を更新しました。'git diff karabiner/' で差分を確認してコミットしてください"
