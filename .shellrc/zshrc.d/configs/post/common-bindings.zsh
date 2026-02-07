#!/usr/bin/env zsh

# Ctrl+Arrow: Word movement (in addition to Alt+Arrow)
# Escape sequences: ^[[1;5C (Ctrl+Right), ^[[1;5D (Ctrl+Left)
for keymap in viins vicmd emacs; do
  bindkey -M $keymap '^[[1;5C' forward-word
  bindkey -M $keymap '^[[1;5D' backward-word
done

# Ctrl-O: Launch opencode (replaces current line and executes)
# Requires unsetting terminal's discard character which normally uses ^O
if [[ -t 0 ]]; then
  command -T stty 2>/dev/null && stty discard undef
fi

opencode-widget() {
  zle kill-whole-line
  BUFFER="oc -c"
  zle accept-line
}
zle -N opencode-widget
for keymap in viins vicmd; do
  bindkey -M $keymap '^O' opencode-widget
done
