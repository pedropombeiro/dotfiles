#!/usr/bin/env zsh

# Avoid slow rebind in autosuggestions
ZSH_AUTOSUGGEST_MANUAL_REBIND=1

# Load autosuggestions and syntax highlighting via zinit turbo mode
# wait'0' = load immediately after prompt, lucid = silent
zinit wait'0' lucid light-mode for \
  atload'_zsh_autosuggest_start' zsh-users/zsh-autosuggestions \
  zdharma-continuum/fast-syntax-highlighting
