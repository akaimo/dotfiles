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

