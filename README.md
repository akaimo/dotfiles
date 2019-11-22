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
- link dotfiles
  - `./dotfilesLink.sh`
  - `echo "[ -f ~/.zshrc.akaimo ] && source ~/.zshrc.akaimo" >> ~/.zshrc`
- install anyenv
  - `make anyenv`
- install language using anyenv and set it globally
  - python 3.6 or later
  - node 12 or later
  - go 1.13 or later
- install vim
  - `make vim`
- install vim plugin
  - `:PlugInstall`

