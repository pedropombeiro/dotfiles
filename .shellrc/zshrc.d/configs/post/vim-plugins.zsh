#!/usr/bin/env zsh

if [ "$(command -v vim)" ]; then
  for plugin in sensible surround fugitive repeat commentary sleuth endwise; do
    if [[ ! -d ~/.vim/pack/tpope/start/${plugin} ]]; then
      mkdir -p ~/.vim/pack/tpope/start
      cd ~/.vim/pack/tpope/start
      git clone https://tpope.io/vim/${plugin}.git
      vim -u NONE -c "helptags ${plugin}/doc" -c q
      cd -
    fi
  done
fi
