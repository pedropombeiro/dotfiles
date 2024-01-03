#!/usr/bin/env zsh

if mise where github-cli >/dev/null 2>&1; then
  if [ ! -f ~/.config/zsh/site-functions/_gh ]; then
    mise exec github-cli --command 'gh completion -s zsh' >~/.config/zsh/site-functions/_gh
    rm -f '~/.zcompdump*' >/dev/null 2>&1
  fi
fi
