#!/usr/bin/env zsh

plugins_installed=0

function install-vim-plugin() {
  local proj="$(basename $1)"
  local target_dir="${HOME}/.vim/pack/bundle/start/${proj}"
  if [[ ! -d "${target_dir}" ]]; then
    mkdir -p "$(dirname "${target_dir}")"
    git clone --depth 1 "$1" "${target_dir}"
    plugins_installed=1
  fi
}

if [ "$(command -v vim)" ]; then
  local urls=(
    'https://github.com/RRethy/vim-illuminate.git'
    'https://github.com/Xuyuanp/nerdtree-git-plugin.git'
    'https://github.com/airblade/vim-gitgutter.git'
    'https://github.com/dense-analysis/ale.git'
    'https://github.com/editorconfig/editorconfig-vim.git'
    'https://github.com/junegunn/fzf'
    'https://github.com/junegunn/fzf.vim'
    'https://github.com/junegunn/vim-easy-align'
    'https://github.com/mtdl9/vim-log-highlighting'
    'https://github.com/nathanaelkane/vim-indent-guides'
    'https://github.com/preservim/nerdcommenter.git'
    'https://github.com/preservim/nerdtree.git'
    'https://github.com/ryanoasis/vim-devicons'
    'https://github.com/skywind3000/asyncrun.vim.git'
    'https://github.com/tiagofumo/vim-nerdtree-syntax-highlight.git'
    'https://github.com/tpope/vim-commentary.git'
    'https://github.com/tpope/vim-dispatch.git'
    'https://github.com/tpope/vim-endwise.git'
    'https://github.com/tpope/vim-eunuch.git'
    'https://github.com/tpope/vim-fugitive.git'
    'https://github.com/tpope/vim-obsession.git'
    'https://github.com/tpope/vim-repeat.git'
    'https://github.com/tpope/vim-sensible.git'
    'https://github.com/tpope/vim-sleuth.git'
    'https://github.com/tpope/vim-speeddating.git'
    'https://github.com/tpope/vim-surround.git'
    'https://github.com/tpope/vim-unimpaired.git'
    'https://github.com/vim-airline/vim-airline.git'
    'https://github.com/vim-test/vim-test'
  )
  if [ -d "${GDK_ROOT}" ]; then
    urls+=('https://github.com/tpope/vim-rails.git')
  fi

  for url in ${urls[@]}; do
    install-vim-plugin "${url}"
  done

  if [[ $plugins_installed -gt 0 ]]; then
    echo 'Updating documentation for Vim plugins...'
    vim -u NONE -c 'helptags ALL' -c q
  fi
fi
