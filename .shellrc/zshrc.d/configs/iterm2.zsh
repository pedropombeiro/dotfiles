#!/usr/bin/env zsh

[[ "${TERM_PROGRAM}" == "iTerm.app" || "${LC_TERMINAL}" == "iTerm2" || -n "${ITERM_SESSION_ID}" ]] || return 0

zshexit() {
  iterm2_badge -c
  iterm2_progress -c
}
