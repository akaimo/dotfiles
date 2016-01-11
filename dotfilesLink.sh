#! /bin/bash
ln -s ~/dotfiles/.vimrc ~/.vimrc
ln -s ~/dotfiles/.bashrc ~/.bashrc
ln -s ~/dotfiles/.bash_profile ~/.bash_profile
# ln -s ~/dotfiles/.vim ~/.vim
if [ ! -d ~/.vim ]; then
  ln -s ~/dotfiles/.vim ~/.vim
fi
ln -s ~/dotfiles/.gitconfig ~/.gitconfig
ln -s ~/dotfiles/.gitignore ~/.gitignore
ln -s ~/dotfiles/.rubocop.yml ~/.rubocop.yml
ln -s ~/dotfiles/.tmux.conf ~/.tmux.conf
ln -s ~/dotfiles/.xvimrc ~/.xvimrc
