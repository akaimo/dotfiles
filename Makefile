.DEFAULT_GOAL := help

.PHONY: help vim brew stow stow-dry-run docker-config ansible-links-cleanup ansible-links-cleanup-dry-run karabiner-backup finicky-install vscode-backup vscode-extensions-backup

help:
	@echo "Available targets:"
	@echo "  make brew                          - Brewfile からパッケージをインストール"
	@echo "  make stow                          - dotfiles のシンボリックリンクを作成"
	@echo "  make stow-dry-run                  - stow の計画を確認 (削除しない)"
	@echo "  make docker-config                 - ~/.docker/config.json に Homebrew の cli-plugins 配置先を idempotent に登録"
	@echo "  make ansible-links-cleanup         - 旧 ansible 由来の symlink を削除"
	@echo "  make ansible-links-cleanup-dry-run - cleanup の計画を確認"
	@echo "  make vim                           - vim-plug / pynvim のセットアップ"
	@echo "  make karabiner-backup              - Karabiner 設定を ~/.config/karabiner/ から karabiner/ に取り込む (アプリ→repo, バックアップ)"
	@echo "  make finicky-install               - finicky 設定を finicky/ から ~/.config/finicky/ に配置して再起動 (repo→アプリ, デプロイ)"
	@echo "  make vscode-backup                 - VSCode 拡張機能リストを vscode/ に取り込む (アプリ→repo, バックアップ)"

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
	# folding 防止のため ~/.config, ~/.config/uv, ~/.config/zed, ~/.claude, ~/.vim,
	# ~/Documents/swiftbar, ~/Library/Application Support/Code/User,
	# ~/Library/Preferences/pnpm を事前に実ディレクトリとして確保する。
	# (~/Documents/swiftbar は SwiftBar プラグイン置き場。ディレクトリごと symlink にされると、
	#  リポジトリ管理外のプラグインを後から追加しづらくなるため個別ファイル単位で symlink させる)
	# (~/Library/Preferences/pnpm は pnpm 11+ が config.yaml を読む macOS 既定パス。
	#  pnpm が将来同ディレクトリに別ファイルを書く可能性に備えて個別ファイル単位で管理する)
	mkdir -p $(HOME)/.config $(HOME)/.config/uv $(HOME)/.config/zed $(HOME)/.claude $(HOME)/.vim $(HOME)/Documents/swiftbar "$(HOME)/Library/Application Support/Code/User" $(HOME)/Library/Preferences/pnpm
	stow -d $(HOME)/dotfiles -t $(HOME) home

stow-dry-run:
	stow -nv -d $(HOME)/dotfiles -t $(HOME) home

# Docker CLI plugin (docker-compose / docker-buildx 等) は Homebrew 管理に統一しているが、
# Homebrew は plugin 本体を $(brew --prefix)/lib/docker/cli-plugins に配置するのに対し、
# Docker CLI が標準で読むのは ~/.docker/cli-plugins のため、このままでは認識されない。
# また Docker の credential helper (docker-credential-osxkeychain, brew の docker-credential-helper
# が提供) を有効にするため credsStore も設定する。
# よって ~/.docker/config.json (実ファイル) に cliPluginsExtraDirs と credsStore を登録する。
# symlink で stow 管理すると docker login 等で書かれる auths がリポジトリ側に混入する危険があるため、
# jq で実ファイルに idempotent に merge する運用とする (jq は Brewfile に同梱)。
# credsStore は既存値があれば尊重し未設定時のみデフォルト値を入れる (Docker Desktop が "desktop" を
# 設定しているケース等を上書きしないため)。
DOCKER_CONFIG_FILE     := $(HOME)/.docker/config.json
DOCKER_CLI_PLUGINS_DIR := /opt/homebrew/lib/docker/cli-plugins
DOCKER_CREDS_STORE     := osxkeychain

docker-config:
	@mkdir -p $(HOME)/.docker
	# 既存の config.json が symlink だと意図せず symlink 先 (例: 古い stow リンク先) を
	# 実ファイル化して上書きしてしまうため、まず存在チェックで停止する。
	@if [ -L "$(DOCKER_CONFIG_FILE)" ]; then \
		target=$$(readlink "$(DOCKER_CONFIG_FILE)"); \
		echo "ERROR: $(DOCKER_CONFIG_FILE) が symlink です (-> $$target)。手動で退避してから再実行してください" && exit 1; \
	fi
	@if [ ! -f "$(DOCKER_CONFIG_FILE)" ]; then echo "{}" > "$(DOCKER_CONFIG_FILE)"; fi
	@tmp="$$(mktemp)" && \
	  jq --arg dir "$(DOCKER_CLI_PLUGINS_DIR)" --arg creds "$(DOCKER_CREDS_STORE)" \
	    '.cliPluginsExtraDirs = ((.cliPluginsExtraDirs // []) as $$dirs | if $$dirs | index($$dir) then $$dirs else $$dirs + [$$dir] end) | .credsStore = (.credsStore // $$creds)' \
	    "$(DOCKER_CONFIG_FILE)" > "$$tmp" && \
	  mv "$$tmp" "$(DOCKER_CONFIG_FILE)"
	@echo "[ok] $(DOCKER_CONFIG_FILE) に cliPluginsExtraDirs / credsStore を確保しました"

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

# VSCode の settings.json は stow 対象 (home/Library/Application Support/Code/User/settings.json)。
# 拡張機能リストだけは code コマンドの出力をバックアップとして管理する。
vscode-backup: vscode-extensions-backup

vscode-extensions-backup:
	mkdir -p vscode
	# code が途中で失敗しても extensions.txt が空で上書きされないよう一時ファイル経由でアトミックに置換する。
	@if command -v code >/dev/null 2>&1; then \
		set -e; \
		code --list-extensions | LC_ALL=C sort > vscode/extensions.txt.tmp; \
		mv vscode/extensions.txt.tmp vscode/extensions.txt; \
		echo "vscode/extensions.txt を更新しました"; \
	else \
		echo "WARN: code コマンドが見つかりません。拡張機能リストの更新はスキップします (Shell Command: 'code' を VSCode のコマンドパレットから PATH に追加してください)"; \
	fi
	@echo "'git diff vscode/' で差分を確認してコミットしてください"
