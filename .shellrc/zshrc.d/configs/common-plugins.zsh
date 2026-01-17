#!/usr/bin/env zsh

# Load autosuggestions and syntax highlighting via zinit (deferred with wait)
zinit wait lucid light-mode for \
  atload'_zsh_autosuggest_start' zsh-users/zsh-autosuggestions \
  zdharma-continuum/fast-syntax-highlighting
