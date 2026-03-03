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

# Ctrl-O: Launch opencode (resume session)
opencode-widget() {
  if [[ -n ${TMUX:-} ]] && command -v tmux >/dev/null; then
    tmux split-window -h -p 40 -c "#{pane_current_path}" "zsh -ilc 'oc -c'"
    zle reset-prompt
    return
  fi

  zle kill-whole-line
  BUFFER="oc -c"
  zle accept-line
}
zle -N opencode-widget
for keymap in viins vicmd; do
  bindkey -M $keymap '^O' opencode-widget
done

# Ctrl-Alt-O: Launch opencode (new session)
opencode-new-widget() {
  if [[ -n ${TMUX:-} ]] && command -v tmux >/dev/null; then
    tmux split-window -h -p 40 -c "#{pane_current_path}" "zsh -ilc 'oc'"
    zle reset-prompt
    return
  fi

  zle kill-whole-line
  BUFFER="oc"
  zle accept-line
}
zle -N opencode-new-widget
for keymap in viins vicmd; do
  bindkey -M $keymap '^[^O' opencode-new-widget
done

# Ctrl-L: Launch lazygit in a new tmux window (falls back to replacing current line)
lazygit-widget() {
  local cmd
  if [[ "$PWD" == "$HOME" ]]; then
    cmd="y lazygit --use-config-dir ~/.config/lazygit"
  else
    cmd="lazygit --use-config-dir ~/.config/lazygit"
  fi

  if [[ -n ${TMUX:-} ]] && command -v tmux >/dev/null; then
    tmux split-window -Z -c "#{pane_current_path}" "zsh -ilc '$cmd'"
    zle reset-prompt
    return
  fi

  zle kill-whole-line
  BUFFER="$cmd"
  zle accept-line
}
zle -N lazygit-widget
for keymap in viins vicmd; do
  bindkey -M $keymap '^L' lazygit-widget
done
