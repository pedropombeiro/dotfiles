#!/usr/bin/env zsh

# Deferred init for tools installed by mise (may not be in PATH at parse time).
# Uses zdharma-continuum/null (a no-op plugin) as a vehicle to run atload code in turbo mode.
zinit ice wait'0a' lucid nocd atload'
  if command -v zoxide &>/dev/null; then
    eval "$(zoxide init zsh --no-cmd)"
    alias j="__zoxide_z"   # autojump compatibility
    alias jj="__zoxide_zi" # interactive mode
  fi
'
zinit light zdharma-continuum/null
