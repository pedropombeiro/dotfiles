#!/usr/bin/env zsh

if [[ -s "${BREW_PREFIX}/etc/grc.zsh" ]]; then
  source "${BREW_PREFIX}/etc/grc.zsh"
elif [[ -s /etc/grc.zsh ]]; then
  source /etc/grc.zsh
fi
