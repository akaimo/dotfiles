#! /bin/bash
sudo chmod +x /usr/share/doc/git/contrib/diff-highlight/diff-highlight
sudo ln -fns /usr/share/doc/git/contrib/diff-highlight/diff-highlight /usr/local/bin/diff-highlight
ln -fns ~/dotfiles/.gitconfig ~/.gitconfig
ln -fns ~/dotfiles/.gitignore ~/.gitignore
