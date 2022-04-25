#!/usr/bin/env bash

DEST_PATH="${HOME}/.vim/pack/bundle/start"

# Customize background color of gruvbox theme to pure black
if [[ $(uname -s) == 'Darwin' ]]; then
  sed -i '' 's/1d2021/000000/g' "${DEST_PATH}/gruvbox/colors/gruvbox.vim"
else
  sed -i 's/1d2021/000000/g' "${DEST_PATH}/gruvbox/colors/gruvbox.vim"
fi
