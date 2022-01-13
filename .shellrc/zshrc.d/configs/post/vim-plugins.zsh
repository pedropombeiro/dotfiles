#!/usr/bin/env zsh

function install-vim-plugin() {
  local target_dir="${HOME}/.vim/pack/$2"
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

  install-vim-plugin 'https://github.com/dense-analysis/ale.git' 'git-plugins/start/ale'
  install-vim-plugin 'https://github.com/preservim/nerdtree.git' 'vendor/start/nerdtree'
  install-vim-plugin 'https://github.com/vim-airline/vim-airline.git' 'dist/start/vim-airline'
  install-vim-plugin 'https://github.com/preservim/nerdcommenter.git' 'vendor/start/nerdcommenter'
  install-vim-plugin 'https://github.com/airblade/vim-gitgutter.git' 'airblade/start/vim-gitgutter'
  install-vim-plugin 'https://github.com/vim-test/vim-test' 'vendor/start/vim-test'
  install-vim-plugin 'https://github.com/junegunn/vim-easy-align' 'vendor/start/vim-easy-align'
  install-vim-plugin 'https://github.com/junegunn/fzf' 'vendor/start/fzf'
  install-vim-plugin 'https://github.com/ryanoasis/vim-devicons' 'vendor/start/vim-devicons'
fi
