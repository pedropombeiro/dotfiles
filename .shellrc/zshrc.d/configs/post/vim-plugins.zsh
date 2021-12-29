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

  if [[ ! -d ~/.vim/pack/git-plugins/start/ale ]]; then
    mkdir -p ~/.vim/pack/git-plugins/start
    git clone --depth 1 https://github.com/dense-analysis/ale.git ~/.vim/pack/git-plugins/start/ale
    vim -u NONE -c "helptags ~/.vim/pack/git-plugins/start/ale/doc" -c q
  fi

  if [[ ! -d ~/.vim/pack/vendor/start/nerdtree ]]; then
    mkdir -p ~/.vim/pack/vendor/start
    git clone --depth 1 https://github.com/preservim/nerdtree.git ~/.vim/pack/vendor/start/nerdtree
    vim -u NONE -c "helptags ~/.vim/pack/vendor/start/nerdtree/doc" -c q
  fi
fi
