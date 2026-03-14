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

# Alt+S: Sesh session picker
sesh-sessions() {
  {
    # ZLE widgets don't have a real tty; reclaim stdin from /dev/tty and
    # duplicate stdout to stdin so fzf can read interactive input
    exec </dev/tty
    exec <&1
    local session
    session=$(sesh list -t -c | fzf --height 40% --reverse --border-label ' sesh ' --border --prompt 'sesh> ')
    zle reset-prompt >/dev/null 2>&1 || true
    [[ -z "$session" ]] && return
    sesh connect "$session"
  }
}

zle -N sesh-sessions  # Register as a ZLE widget so bindkey can use it
for keymap in emacs vicmd viins; do
  bindkey -M $keymap '\es' sesh-sessions  # Alt+S
done

# Yank current command line to system clipboard (triggered by tmux prefix+Y).
# \e[Y is a custom (non-standard) escape sequence sent by tmux send-keys, chosen
# to avoid conflicts with real terminal sequences.
# Uses clipcopy from OMZ clipboard lib (pbcopy on macOS, OSC 52 on Linux/QNAP).
yank-buffer-to-clipboard() {
  if [[ -n "$BUFFER" ]]; then
    printf '%s' "$BUFFER" | clipcopy
    zle -M "Copied command to clipboard"
  else
    zle -M "Nothing to copy"
  fi
}
zle -N yank-buffer-to-clipboard  # Register as a ZLE widget so bindkey can use it
for keymap in viins vicmd; do
  bindkey -M $keymap '\e[Y' yank-buffer-to-clipboard
done
