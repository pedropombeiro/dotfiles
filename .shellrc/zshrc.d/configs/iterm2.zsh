#!/usr/bin/env zsh

[[ "${TERM_PROGRAM}" == "iTerm.app" || "${LC_TERMINAL}" == "iTerm2" || -n "${ITERM_SESSION_ID}" ]] || return 0

autoload -Uz add-zsh-hook

_iterm2_clear_indicators() {
  iterm2_badge -c
  iterm2_progress -c
}

add-zsh-hook precmd _iterm2_clear_indicators

zshexit() {
  iterm2_badge -c
  iterm2_progress -c
}
