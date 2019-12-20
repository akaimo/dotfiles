# dotfiles

## usage
- (mac only) install homebrew
  - https://brew.sh/index_ja
- install git
  - mac: `brew install git`
- clone dotfiles
  - `git clone --recursive https://github.com/akaimo/dotfiles.git ~/dotfiles`
- install ansible
  - mac: `brew install ansible`
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

