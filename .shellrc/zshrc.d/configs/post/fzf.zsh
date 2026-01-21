#!/usr/bin/env zsh

# Load fzf after turbo plugins to prevent keybinding conflicts
zinit wait'0b' lucid atload'source <(fzf --zsh)' light-mode for \
  zdharma-continuum/null

# CTRL-G - Paste the selected git branch into the command line
__fzf_bsel() {
  local cmd="${FZF_CTRL_G_COMMAND:-"command git branch -a 2> /dev/null | cut -b2-"}"
  setopt localoptions pipefail no_aliases 2> /dev/null
  local item
  eval "$cmd" | FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-40%} --reverse --bind=ctrl-z:ignore ${FZF_DEFAULT_OPTS-} ${FZF_CTRL_G_OPTS-}" $(__fzfcmd) -m "$@" | while read item; do
    echo -n "${(q)item} "
  done
  local ret=$?
  echo
  return $ret
}

__fzfcmd() {
  [ -n "${TMUX_PANE-}" ] && { [ "${FZF_TMUX:-0}" != 0 ] || [ -n "${FZF_TMUX_OPTS-}" ]; } &&
    echo "fzf-tmux ${FZF_TMUX_OPTS:--d${FZF_TMUX_HEIGHT:-40%}} -- " || echo "fzf"
}

fzf-branch-widget() {
  LBUFFER="${LBUFFER}$(__fzf_bsel)"
  local ret=$?
  zle reset-prompt
  return $ret
}
zle     -N            fzf-branch-widget
bindkey -M emacs '^G' fzf-branch-widget
bindkey -M vicmd '^G' fzf-branch-widget
bindkey -M viins '^G' fzf-branch-widget
