#!/usr/bin/env zsh

(( $+commands[fzf] )) || return

# Cache `fzf --zsh` output, stripping Ctrl-R bindings (atuin owns ^R).
# Regenerates when the fzf binary is newer or this script is updated.
_fzf_init="${XDG_DATA_HOME:-$HOME/.local/share}/fzf/init.zsh"

if [[ ! -f "$_fzf_init" || "$_fzf_init" -ot "$commands[fzf]" || "$_fzf_init" -ot "${(%):-%x}" ]]; then
  mkdir -p "${_fzf_init:h}"
  fzf --zsh | grep -v "bindkey.*'\^R'" >"$_fzf_init"
fi

# Load fzf after turbo plugins to prevent keybinding conflicts
zinit wait'0b' lucid nocd atload"source $_fzf_init" light-mode for \
  zdharma-continuum/null

unset _fzf_init

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
zle     -N            fzf-branch-widget  # Register as a ZLE widget so bindkey can use it
bindkey -M emacs '^G' fzf-branch-widget
bindkey -M vicmd '^G' fzf-branch-widget
bindkey -M viins '^G' fzf-branch-widget
