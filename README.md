# dotfiles

## usage
- (mac only) install homebrew
  - https://brew.sh/ja/
- install tools
  - mac: `brew install git ansible`
  - debian: `apt install zsh ansible make git`
- clone dotfiles
  - `git clone --recursive https://github.com/akaimo/dotfiles.git ~/dotfiles`
- run basic playbook
  - `make`
  - `exec $SHELL -l`
- install vim
  - `make vim`
- (mac only) install pkg-based casks manually
  - `brew install --cask karabiner-elements google-japanese-ime tailscale-app`
  - Ansible 経由では TTY が無く `sudo installer -pkg` が失敗するため、対話ターミナルから手動で実行する
- install vim plugin
  - `:PlugInstall`
- (option) use ssh
  - `git remote set-url origin git@github.com:akaimo/dotfiles.git`

