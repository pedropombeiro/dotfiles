#!/usr/bin/env zsh

zsh-defer -c "
  # Remove problematic aliases
  if alias duf >/dev/null; then
    unalias duf
  fi
  if alias t >/dev/null; then
    # Allow ~/.shellrc/zshrc.d/functions/t to override the t alias
    unalias t
  fi

  if alias gf >/dev/null; then
    unalias gf # Overriden as a more specialized function
  fi
  if alias gfa >/dev/null; then
    unalias gfa # Overriden as a more specialized function
  fi
"
