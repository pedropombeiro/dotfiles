#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source "${SCRIPT_DIR}/install-vim-plugin.sh"

if [ "$(command -v vim)" -o "$(command -v nvim)" ]; then
  urls=(
    'https://github.com/airblade/vim-gitgutter.git'
    'https://github.com/bfontaine/Brewfile.vim.git'
    'https://github.com/dense-analysis/ale.git'
    'https://github.com/editorconfig/editorconfig-vim.git'
    'https://github.com/farmergreg/vim-lastplace.git'
    'https://github.com/junegunn/fzf'
    'https://github.com/junegunn/fzf.vim'
    'https://github.com/junegunn/vim-easy-align'
    'https://github.com/mtdl9/vim-log-highlighting'
    'https://github.com/nathanaelkane/vim-indent-guides'
    'https://github.com/nishigori/increment-activator.git'
    'https://github.com/preservim/nerdcommenter.git'
    'https://github.com/preservim/nerdtree.git'
    'https://github.com/RRethy/vim-illuminate.git'
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
    'https://github.com/wsdjeg/vim-fetch.git'
    'https://github.com/Xuyuanp/nerdtree-git-plugin.git'
  )
  plugins_installed=0

  for url in ${urls[@]}; do
    install-vim-plugin "${url}"
    if [[ $? -eq 1 ]]; then
      plugins_installed=1
    fi
  done

  if [[ $plugins_installed -gt 0 ]]; then
    echo 'Updating documentation for Vim plugins...'
    nvim -u NONE -c 'helptags ALL' -c q
  fi
fi
