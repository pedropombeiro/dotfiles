#!/usr/bin/env zsh

if command -v brew > /dev/null; then
  plugins+=(brew)
fi

PATH="/usr/local/sbin:$PATH"
