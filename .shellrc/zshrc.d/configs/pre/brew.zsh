#!/usr/bin/env zsh

if command -v brew > /dev/null; then
  BREW_PREFIX="$(brew --prefix 2>/dev/null)"
fi
