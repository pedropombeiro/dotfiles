#!/usr/bin/env zsh

# Load fzf after turbo plugins to prevent keybinding conflicts
zinit wait'0b' lucid atload'source <(fzf --zsh)' light-mode for \
  zdharma-continuum/null
