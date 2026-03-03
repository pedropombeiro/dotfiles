#!/usr/bin/env zsh

# Ctrl+Arrow: Word movement (in addition to Alt+Arrow)
# Escape sequences: ^[[1;5C (Ctrl+Right), ^[[1;5D (Ctrl+Left)
for keymap in viins vicmd emacs; do
  bindkey -M $keymap '^[[1;5C' forward-word
  bindkey -M $keymap '^[[1;5D' backward-word
done
