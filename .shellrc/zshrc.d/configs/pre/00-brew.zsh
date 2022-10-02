#!/usr/bin/env zsh

if [[ -z $HOMEBREW_PREFIX ]]; then
  if command -v brew > /dev/null; then
    export HOMEBREW_PREFIX="$(brew --prefix 2>/dev/null)"
  fi
fi
