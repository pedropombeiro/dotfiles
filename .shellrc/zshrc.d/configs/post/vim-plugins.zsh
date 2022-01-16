#!/usr/bin/env zsh

function install-vim-plugin() {
  local proj="$(basename $1)"
  local owner="$(basename "$(dirname "$1")")"
  local target_dir="${HOME}/.vim/pack/${owner}/start/${proj}"
  if [[ ! -d "${target_dir}" ]]; then
    mkdir -p "$(dirname "${target_dir}")"
    git clone --depth 1 "$1" "${target_dir}"
    vim -u NONE -c "helptags ${target_dir}/doc" -c q
  fi
}

if [ "$(command -v vim)" ]; then
  for plugin in sensible surround fugitive repeat commentary sleuth endwise rails dispatch; do
    if [[ ! -d ~/.vim/pack/tpope/start/${plugin} ]]; then
      mkdir -p ~/.vim/pack/tpope/start
      cd ~/.vim/pack/tpope/start
      git clone https://tpope.io/vim/${plugin}.git
      vim -u NONE -c "helptags ${plugin}/doc" -c q
      cd -
    fi
  done

  local urls=(
    'https://github.com/dense-analysis/ale.git'
    'https://github.com/preservim/nerdtree.git'
    'https://github.com/vim-airline/vim-airline.git'
    'https://github.com/preservim/nerdcommenter.git'
    'https://github.com/airblade/vim-gitgutter.git'
    'https://github.com/vim-test/vim-test'
    'https://github.com/junegunn/vim-easy-align'
    'https://github.com/junegunn/fzf'
    'https://github.com/junegunn/fzf.vim'
    'https://github.com/ryanoasis/vim-devicons'
    'https://github.com/nathanaelkane/vim-indent-guides'
  )
  for url in ${urls[@]}; do
    install-vim-plugin "${url}"
  done
fi
