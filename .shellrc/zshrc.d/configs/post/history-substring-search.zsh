#!/usr/bin/env zsh

# Load history-substring-search via zinit (deferred, with vi keybindings)
zinit wait lucid light-mode for \
  atload'bindkey -M vicmd "k" history-substring-search-up; bindkey -M vicmd "j" history-substring-search-down' \
  zsh-users/zsh-history-substring-search
