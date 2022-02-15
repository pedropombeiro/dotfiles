#!/usr/bin/env bash

# Map C-x C-e to the edit-command-line function
autoload -U edit-command-line
zle -N edit-command-line
bindkey '^x^e' edit-command-line
