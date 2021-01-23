# dotfiles

## usage
- (mac only) install homebrew
  - https://brew.sh/index_ja
- install tools
  - mac: `brew install git ansible`
  - debian: `apt install zsh ansible make`
- clone dotfiles
  - `git clone --recursive https://github.com/akaimo/dotfiles.git ~/dotfiles`
- run basic playbook
  - `make`
  - `exec $SHELL -l`
- install anyenv and language
  - `make anyenv`
  - `exec $SHELL -l`
- install vim
  - `make vim`
- install vim plugin
  - `:PlugInstall`
- (option) use ssh
  - `git remote set-url origin git@github.com:akaimo/dotfiles.git`

