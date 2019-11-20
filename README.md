# dotfiles

## usage
- (mac only) install homebrew
  - https://brew.sh/index_ja
- clone dotfiles
  - `git clone --recursive https://github.com/akaimo/dotfiles.git ~/dotfiles`
- install ansible
  - mac: `brew install ansible`
- run basic playbook
  - `make`
- link dotfiles
  - `./dotfilesLink.sh`
  - `echo "[ -f ~/.zshrc.akaimo ] && source ~/.zshrc.akaimo" >> ~/.zshrc`

## vim
```
# setup vim-plug
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
:PlugInstall
```

