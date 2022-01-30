#!/usr/bin/env bash

if [ -f ~/.config/nvim/init.vim ]; then
  # Redirect neovim to vim configuration
  cat << EOF > ${HOME}/.config/nvim/init.vim
set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath
source ~/.vimrc
EOF
fi
