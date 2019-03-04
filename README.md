# dotfiles
## install
```
./dotfilesLink.sh
```

## vim
```
# install vim
brew install ghq lua python3
./install_vim.sh
exec $SHELL -l

# setup vim plugin
curl https://raw.githubusercontent.com/Shougo/neobundle.vim/master/bin/install.sh > install.sh
sh ./install.sh
:NeoBundleInstall
```

