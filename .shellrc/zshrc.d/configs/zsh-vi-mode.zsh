#!/usr/bin/env zsh

# Set beam cursor immediately so there's no shape flicker before vi-mode loads.
# \e[5 q = blinking beam (matches zsh-vi-mode's insert-mode cursor)
printf '\e[5 q'

# Load zsh-vi-mode via zinit turbo. Loads ~10ms after prompt appears,
# fast enough that vi bindings are ready before the user starts typing.
zinit ice wait'0' lucid depth=1
zinit light jeffreytse/zsh-vi-mode
