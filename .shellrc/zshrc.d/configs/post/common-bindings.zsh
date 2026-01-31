#!/usr/bin/env zsh

# Ctrl-O: Launch opencode (replaces current line and executes)
# Requires unsetting terminal's discard character which normally uses ^O
if [[ -t 0 ]]; then
  command -T stty 2>/dev/null && stty discard undef
fi

opencode-widget() {
  zle kill-whole-line
  BUFFER="opencode"
  zle accept-line
}
zle -N opencode-widget
for keymap in viins vicmd; do
  bindkey -M $keymap '^O' opencode-widget
done
