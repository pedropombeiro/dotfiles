#!/usr/bin/env zsh

autoload -U edit-command-line
zle -N edit-command-line
# Assign Esc-v-v to edit-command-line
bindkey -M vicmd v edit-command-line
