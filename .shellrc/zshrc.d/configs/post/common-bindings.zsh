#!/usr/bin/env zsh

# Unset terminal special characters that conflict with app keybindings
# C-\: SIGQUIT (conflicts with Neovim file explorer toggle)
if [[ -t 0 ]]; then
  stty quit undef
fi

# Ctrl+Arrow: Word movement (in addition to Alt+Arrow)
# Escape sequences: ^[[1;5C (Ctrl+Right), ^[[1;5D (Ctrl+Left)
for keymap in viins vicmd emacs; do
  bindkey -M $keymap '^[[1;5C' forward-word
  bindkey -M $keymap '^[[1;5D' backward-word
done
