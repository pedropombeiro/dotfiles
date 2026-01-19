#!/usr/bin/env zsh

# Avoid slow rebind in autosuggestions
ZSH_AUTOSUGGEST_MANUAL_REBIND=1

# Load autosuggestions and syntax highlighting via zinit turbo mode
# wait'0' = load immediately after prompt, lucid = silent
zinit wait'0' lucid light-mode for \
  atload'_zsh_autosuggest_start' zsh-users/zsh-autosuggestions \
  zdharma-continuum/fast-syntax-highlighting

# fzf-tab: replace zsh completion menu with fzf popup
zinit wait'0a' lucid light-mode for \
  Aloxaf/fzf-tab

zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always --icons $realpath'
zstyle ':fzf-tab:complete:eza:*' fzf-preview '[[ -d $realpath ]] && eza -1 --color=always --icons $realpath || bat --color=always --style=numbers --line-range=:500 $realpath'

# OMZ completions only (no aliases)
zinit wait lucid as"completion" for \
  OMZP::yarn/_yarn \
  OMZP::redis-cli/_redis-cli
