#!/usr/bin/env zsh

if [[ -s "${BREW_PREFIX}/etc/grc.zsh" ]]; then
  source "${BREW_PREFIX}/etc/grc.zsh"
elif [[ -s /etc/grc.zsh ]]; then
  source /etc/grc.zsh
fi

# Unset make, as the grc implementation gets confused when invoking the yadm update.sh script through it
unset -f make 2>/dev/null
