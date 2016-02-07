#! /bin/bash
ln -fns ~/dotfiles/.vimrc ~/.vimrc
ln -fns ~/dotfiles/.bashrc ~/.bashrc
ln -fns ~/dotfiles/.bash_profile ~/.bash_profile
# ln -s ~/dotfiles/.vim ~/.vim
if [ ! -d ~/.vim ]; then
  ln -s ~/dotfiles/.vim ~/.vim
fi
ln -fns ~/dotfiles/.gitconfig ~/.gitconfig
ln -fns ~/dotfiles/.gitignore ~/.gitignore
ln -fns ~/dotfiles/.rubocop.yml ~/.rubocop.yml
ln -fns ~/dotfiles/.tmux.conf ~/.tmux.conf
ln -fns ~/dotfiles/.xvimrc ~/.xvimrc
