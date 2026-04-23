# dotfiles

## usage
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
  - (初回のみ) 過去の Ansible が作った古いリンク(dotfiles 由来 + prezto 由来)を削除する: `make ansible-links-cleanup-dry-run` で確認してから `make ansible-links-cleanup`
  - 先に `make stow-dry-run` で想定リンクを確認する
  - 実ファイル/ディレクトリが邪魔する場合は手動で退避してから再実行する: `mv ~/.xxx ~/.xxx.backup.$(date +%Y%m%d%H%M%S)`
  - `make stow`
- (option) prezto 撤去後のクリーンアップ
  - `rm -rf ~/.zprezto` (以前 ansible が clone していたリポジトリの残骸を消す)
  - `rm -f ~/.cache/zsh/zcompdump*` (新しく入った zsh-completions を反映させるため、補完キャッシュを一度消す)
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

