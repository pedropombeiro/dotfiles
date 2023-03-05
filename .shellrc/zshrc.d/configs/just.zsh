#!/usr/bin/env zsh

if [ ! -f ~/.config/zsh/site-functions/_just ]; then
  rtx exec just --command 'just --completions zsh' > ~/.config/zsh/site-functions/_just
  rm -f '~/.zcompdump*' >/dev/null 2>&1
fi
