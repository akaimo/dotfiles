# dotfiles

## 新規構築 (新規マシンでのセットアップ)

- install homebrew
  - https://brew.sh/ja/
- install tools
  - `brew install git`
- clone dotfiles
  - `git clone --recursive https://github.com/akaimo/dotfiles.git ~/dotfiles`
- 以降の手順は `~/dotfiles` ディレクトリで実行する
  - `cd ~/dotfiles`
- install homebrew packages via Brewfile
  - `make brew`
  - pkg ベースの cask(karabiner-elements, google-japanese-ime, tailscale-app)は sudo プロンプトが出るため、対話ターミナルから実行する
  - インストール後、macOS の「プライバシーとセキュリティ」で追加許可が必要な場合あり
- create dotfile symlinks via GNU Stow
  - 先に `make stow-dry-run` で想定リンクを確認する
  - 実ファイル/ディレクトリが邪魔する場合は手動で退避してから再実行する: `mv ~/.xxx ~/.xxx.backup.$(date +%Y%m%d%H%M%S)`
  - `make stow`
- set login shell (必要なら)
  - macOS は既定で zsh だが、他シェルのままなら `chsh -s /bin/zsh`
- reload shell
  - `exec $SHELL -l`
- mise
  - `mise i`
- install vim
  - `make vim`
  - vim-plug を `~/.vim/autoload/` と `~/.local/share/nvim/site/autoload/` に配置し、nvim 用の Python provider (pynvim) を `~/.local/share/nvim/venv/` に uv で用意する
  - 事前に `mise i` で uv が入っている必要あり
- install vim plugin
  - vim / nvim を起動して `:PlugInstall`
  - nvim では初回のみ `:UpdateRemotePlugins` を実行して remote plugin manifest を生成してから nvim を再起動 (deoplete.nvim 等の Python remote plugin 用)
- (option) use ssh
  - `git remote set-url origin git@github.com:akaimo/dotfiles.git`

## ansibleからの移行 (既存マシンからの移行手順)

ansible で構築済みの環境から本構成へ乗り換える場合、以下のクリーンアップを先に実施してから、新規構築と同じ `make stow` / `make vim` を実行する。

- dotfiles リポジトリを最新化
  - `cd ~/dotfiles && git pull`
- Brewfile のパッケージを反映 (stow / zsh プラグイン等が新規追加されているため)
  - `make brew`
- 過去の Ansible が作った古いリンク(dotfiles 由来 + prezto 由来)を削除する
  - `make ansible-links-cleanup-dry-run` で確認してから `make ansible-links-cleanup`
- prezto の残骸を削除
  - `rm -rf ~/.zprezto` (以前 ansible が clone していたリポジトリの残骸を消す)
  - `rm -f ~/.cache/zsh/zcompdump*` (新しく入った zsh-completions を反映させるため、補完キャッシュを一度消す)
- 新しい構成でシンボリックリンクを作り直す
  - 先に `make stow-dry-run` で想定リンクを確認する
  - 実ファイル/ディレクトリが邪魔する場合は手動で退避してから再実行する: `mv ~/.xxx ~/.xxx.backup.$(date +%Y%m%d%H%M%S)`
  - `make stow`
- reload shell
  - `exec $SHELL -l`
- vim 周りを再セットアップ
  - `make vim`
  - 続けて vim / nvim を起動して `:PlugInstall`、nvim では初回のみ `:UpdateRemotePlugins` を実行

## Karabiner 設定のバックアップ

Karabiner-Elements の設定 (`~/.config/karabiner/karabiner.json`) は stow 対象ではなく、リポジトリ直下の `karabiner/` に「バックアップとしてコピー」して git 履歴で過去の設定を追える運用にしている。

- バックアップを取る
  - `make karabiner-backup`
  - `~/.config/karabiner/karabiner.json` を `karabiner/karabiner.json` へ上書きコピーする
  - `git diff karabiner/` で差分を確認し、問題なければコミットする
- 復元する (新しいマシン等)
  - Karabiner-Elements を一度終了してから実行 (起動中は書き戻しで上書きされる可能性があるため)
  - `mkdir -p ~/.config/karabiner && cp karabiner/karabiner.json ~/.config/karabiner/karabiner.json`
  - Karabiner-Elements を再起動し、端末固有のデバイス設定 (vendor/product ID 指定のキーバインド等) が復元先のキーボードで期待通り効くか確認する
- 注意
  - これは stow 対象ではないため、手動で `make karabiner-backup` を叩かない限り更新されない (Karabiner がファイルをアトミック rename で書き戻し symlink が壊れる問題を避けるため、あえて同期しない構成)
  - `~/.config/karabiner/automatic_backups/` は Karabiner が日次で作る自動バックアップで、本リポジトリの管理対象外
