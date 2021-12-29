#!/usr/bin/env zsh

function install-vim-plugin() {
  local target_dir="~/.vim/pack/$2"
  if [[ ! -d "${target_dir}" ]]; then
    mkdir -p "$(dirname "${target_dir}")"
    git clone --depth 1 "$1" "${target_dir}"
    vim -u NONE -c "helptags ${target_dir}/doc" -c q
  fi
}

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

  install-vim-plugin 'https://github.com/dense-analysis/ale.git' 'git-plugins/start/ale'
  install-vim-plugin 'https://github.com/preservim/nerdtree.git' 'vendor/start/nerdtree'
  install-vim-plugin 'https://github.com/vim-airline/vim-airline.git' 'dist/start/vim-airline'
fi
