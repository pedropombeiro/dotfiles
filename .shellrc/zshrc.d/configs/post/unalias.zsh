#!/usr/bin/env zsh

# Remove problematic aliases
if alias duf >/dev/null; then
  unalias duf
fi
if alias t >/dev/null; then
  # Allow ~/.shellrc/zshrc.d/functions/t to override the t alias
  unalias t
fi

unalias gf # Overriden as a more specialized function
unalias gfa # Overriden as a more specialized function
