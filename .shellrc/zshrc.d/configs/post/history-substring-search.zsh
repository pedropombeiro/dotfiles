#!/usr/bin/env zsh

# https://github.com/zsh-users/zsh-history-substring-search/blob/master/README.md#install
plugins+=(history-substring-search)

bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down
