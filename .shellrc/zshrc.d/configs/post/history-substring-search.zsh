#!/usr/bin/env zsh

# https://github.com/zsh-users/zsh-history-substring-search/blob/master/README.md#install
zsh-defer -a -t 0.1 source $ZSH/plugins/history-substring-search/history-substring-search.zsh

bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down
