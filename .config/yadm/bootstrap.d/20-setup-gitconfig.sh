#!/usr/bin/env bash

if ! grep "= ~/.config/dotfiles/git/gitconfig^" ~/.gitconfig >/dev/null; then
  cat << EOF > ~/.gitconfig
[include]
  path = ~/.config/dotfiles/git/gitconfig
EOF
fi
