#!/usr/bin/env zsh

if [[ -s /usr/local/etc/grc.zsh ]]; then
  source /usr/local/etc/grc.zsh
else
  BREW_PREFIX="$(brew --prefix 2>/dev/null)"
  if [[ -s "${BREW_PREFIX}/etc/grc.zsh" ]]; then
    source "${BREW_PREFIX}/etc/grc.zsh"
  elif [[ -s /etc/grc.zsh ]]; then
    source /etc/grc.zsh
  fi
fi
