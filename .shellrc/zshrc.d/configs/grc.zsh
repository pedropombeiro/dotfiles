#!/usr/bin/env zsh

if [[ -s /usr/local/etc/grc.zsh ]]; then
  source /usr/local/etc/grc.zsh
elif [[ -s "/etc/grc.zsh" ]]; then
  source /etc/grc.zsh
fi
