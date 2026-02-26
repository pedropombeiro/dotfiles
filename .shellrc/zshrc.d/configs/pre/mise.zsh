#!/usr/bin/env zsh

zinit ice wait'0a' lucid atload'
  if command -v zoxide &>/dev/null; then
    eval "$(zoxide init zsh --no-cmd)"
    alias j="__zoxide_z"   # autojump compatibility
    alias jj="__zoxide_zi" # interactive mode
  fi
  command -v gh >/dev/null && eval "$(gh completion -s zsh)"
'
zinit light zdharma-continuum/null
