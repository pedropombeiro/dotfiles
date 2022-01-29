#!/usr/bin/env bash

if [ -x "$(command -v nvim)" ]; then
  # Modern Vim
  if [ -n "$NVIM_LISTEN_ADDRESS" ]; then
    if [ -x "$(command -v nvr)" ]; then
      alias nvim=nvr
    else
      alias nvim="echo 'No nesting allowed!'"
    fi
  fi
fi
