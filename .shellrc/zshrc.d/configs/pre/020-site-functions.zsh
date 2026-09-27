#!/usr/bin/env zsh

[[ -d $HOME/.config/zsh/site-functions ]] || mkdir -p $HOME/.config/zsh/site-functions
fpath=(
  ${HOMEBREW_PREFIX:+$HOMEBREW_PREFIX/share/zsh/site-functions}
  $HOME/.config/zsh/site-functions
  $fpath
)
