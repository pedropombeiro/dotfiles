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
fi
