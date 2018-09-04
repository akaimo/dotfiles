# dotfiles
## install
```
./dotfilesLink.sh
```

## vim
```
# install vim
brew install vim --with-lua
sudo mv /usr/bin/vim /usr/bin/vim_bk
sudo ln /usr/local/Cellar/vim/8.0.1100/bin/vim /usr/bin/vim

# setup vim plugin
curl https://raw.githubusercontent.com/Shougo/neobundle.vim/master/bin/install.sh > install.sh
sh ./install.sh
:NeoBundleInstall
```

