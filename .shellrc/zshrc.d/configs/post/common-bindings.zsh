#!/usr/bin/env zsh

# Unset terminal special characters that conflict with app keybindings
# C-\: SIGQUIT (conflicts with Neovim file explorer toggle)
if [[ -t 0 ]] && command -v stty &>/dev/null; then
  stty quit undef
fi

# Ctrl+Arrow: Word movement (in addition to Alt+Arrow)
# Escape sequences: ^[[1;5C (Ctrl+Right), ^[[1;5D (Ctrl+Left)
for keymap in viins vicmd emacs; do
  bindkey -M $keymap '^[[1;5C' forward-word
  bindkey -M $keymap '^[[1;5D' backward-word
done

# Yank current command line to system clipboard (triggered by tmux prefix+Y)
# Uses \e[Y as a custom escape sequence sent by tmux send-keys
# Uses clipcopy from OMZ clipboard lib (pbcopy on macOS, OSC 52 on Linux/QNAP)
yank-buffer-to-clipboard() {
  if [[ -n "$BUFFER" ]]; then
    printf '%s' "$BUFFER" | clipcopy
    zle -M "Copied command to clipboard"
  else
    zle -M "Nothing to copy"
  fi
}
zle -N yank-buffer-to-clipboard
for keymap in viins vicmd; do
  bindkey -M $keymap '\e[Y' yank-buffer-to-clipboard
done
