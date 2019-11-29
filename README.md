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
- setup prezto
  - https://github.com/sorin-ionescu/prezto
- link dotfiles
  - `./dotfilesLink.sh`
  - `echo "[ -f ~/.zshrc.akaimo ] && source ~/.zshrc.akaimo" >> ~/.zshrc`
- install anyenv and language
  - `make anyenv`
- install vim
  - `make vim`
- install vim plugin
  - `:PlugInstall`

