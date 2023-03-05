#!/usr/bin/env zsh

if rtx where github-cli >/dev/null 2>&1; then
  if [ ! -f  ~/.config/zsh/site-functions/_gh ]; then
    rtx exec github-cli --command 'gh completion -s zsh' > ~/.config/zsh/site-functions/_gh
    rm -f '~/.zcompdump*' >/dev/null 2>&1
  fi
fi
