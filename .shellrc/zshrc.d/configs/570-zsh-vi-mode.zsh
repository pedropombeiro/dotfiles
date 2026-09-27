#!/usr/bin/env zsh

# Set beam cursor immediately so there's no shape flicker before vi-mode loads.
# \e[5 q = blinking beam (matches zsh-vi-mode's insert-mode cursor)
printf '\e[5 q'

# Load zsh-vi-mode in the first turbo group, before fzf and Atuin bindings.
zinit ice wait'0' lucid depth=1
zinit light jeffreytse/zsh-vi-mode
