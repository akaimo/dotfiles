# dotfiles

## usage
- (mac only) install homebrew
  - https://brew.sh/ja/
- install tools
  - mac: `brew install git ansible`
  - debian: `apt install zsh ansible make git`
- clone dotfiles
  - `git clone --recursive https://github.com/akaimo/dotfiles.git ~/dotfiles`
- 以降の手順は `~/dotfiles/ansible` ディレクトリで実行する
  - `cd ~/dotfiles/ansible`
- (mac only) install homebrew packages via Brewfile
  - `make brew`
  - pkg ベースの cask(karabiner-elements, google-japanese-ime, tailscale-app)は sudo プロンプトが出るため、対話ターミナルから実行する
  - インストール後、macOS の「プライバシーとセキュリティ」で追加許可が必要な場合あり
- create dotfile symlinks via GNU Stow
  - (初回のみ) 過去の Ansible が作った古いリンクを削除する: `make ansible-links-cleanup-dry-run` で確認してから `make ansible-links-cleanup`
  - 先に `make stow-dry-run` で想定リンクを確認する
  - 実ファイル/ディレクトリが邪魔する場合は手動で退避してから再実行する: `mv ~/.xxx ~/.xxx.backup.$(date +%Y%m%d%H%M%S)`
  - `make stow`
- run basic playbook
  - `make`
  - `exec $SHELL -l`
- mise
  - `mise i`
- install vim
  - `make vim`
- install vim plugin
  - `:PlugInstall`
- (option) use ssh
  - `git remote set-url origin git@github.com:akaimo/dotfiles.git`

