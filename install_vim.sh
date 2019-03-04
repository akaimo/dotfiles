#!/usr/bin/env bash

function makeInstallLatestVim() {
  ghq get vim/vim --update;
  pushd `ghq list vim/vim --full-path`;
  git checkout master;

  ./configure \
    --with-features=huge \
    --enable-luainterp \
    --with-lua-prefix=/usr/local \
    --enable-perlinterp \
    --enable-pythoninterp \
    --enable-python3interp \
    --enable-rubyinterp \
    --enable-fail-if-missing;

  make;
  sudo make install;
  popd
}

makeInstallLatestVim
