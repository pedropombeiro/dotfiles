#!/usr/bin/env zsh

if command -v mise &>/dev/null; then
  mise_bin=$(command -v mise)
  mise_completion=~/.config/zsh/site-functions/_mise
  if [[ ! -f $mise_completion || $mise_completion -ot $mise_bin ]]; then
    mise complete -s zsh >$mise_completion
    rm -f ~/.zcompdump* >/dev/null 2>&1
  fi
fi
