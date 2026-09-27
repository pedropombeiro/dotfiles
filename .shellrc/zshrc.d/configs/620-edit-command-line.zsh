#!/usr/bin/env zsh

# Lazy-load the edit-command-line function from $fpath.
# -U prevents alias expansion while loading, so commands inside the function are
# parsed literally (e.g. `ls` stays `ls` even if you have `alias ls=eza`).
autoload -U edit-command-line
zle -N edit-command-line  # Register as a ZLE widget so bindkey can use it
# Assign Esc-v-v to edit-command-line
bindkey -M vicmd v edit-command-line
