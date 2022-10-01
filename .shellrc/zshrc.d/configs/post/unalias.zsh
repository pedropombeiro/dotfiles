#!/usr/bin/env zsh

# Remove problematic aliases
if alias duf >/dev/null; then
  unalias duf
fi
if alias t >/dev/null; then
  unalias t
fi
