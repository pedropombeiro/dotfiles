#!/usr/bin/env sh

# iTerm2 badge, progress-bar, and notification helpers.
#
# Sourced by both bash (yadm bootstrap) and sh (git-ai-commit-msg), so this
# stays POSIX: no `local`, no `[[ ]]`. The zsh equivalents live in
# ~/.shellrc/zshrc.d/functions/iterm2_{progress,badge,notify} for interactive use.
#
# Usage:
#   iterm2_progress <percent>|-i|-e [percent]|-w <percent>|-c
#   iterm2_badge <text>|-c
#   iterm2_notify <message>

# shellcheck shell=sh
# shellcheck disable=SC2059  # OSC prefixes are intentionally part of the format

_iterm2_active() {
  [ "${TERM_PROGRAM:-}" = "iTerm.app" ] || [ "${LC_TERMINAL:-}" = "iTerm2" ] || [ -n "${ITERM_SESSION_ID:-}" ]
}

# Sets _ITERM2_OSC/_ITERM2_ST. Distinctly named because POSIX sh has no `local`.
# Uses \033 rather than \e: dash's printf does not understand \e.
_iterm2_osc() {
  if [ -n "${TMUX:-}" ]; then
    _ITERM2_OSC="\033Ptmux;\033\033]"
    _ITERM2_ST="\a\033\\"
  else
    _ITERM2_OSC="\033]"
    _ITERM2_ST="\a"
  fi
}

# The redirect is what fails when there is no controlling terminal (as under
# `mise run`), and the shell reports that on its own stderr rather than the
# command's. Nest the group so the outer 2>/dev/null suppresses it.
_iterm2_write() {
  {
    { printf "$@"; } >"${ITERM2_TTY:-/dev/tty}"
  } 2>/dev/null || true
}

iterm2_progress() {
  _iterm2_active || return 0
  _iterm2_osc
  case "${1:-}" in
  -i) _iterm2_write "${_ITERM2_OSC}9;4;3${_ITERM2_ST}" ;;
  -e)
    if [ -n "${2:-}" ]; then
      _iterm2_write "${_ITERM2_OSC}9;4;2;%d${_ITERM2_ST}" "${2}"
    else
      _iterm2_write "${_ITERM2_OSC}9;4;2${_ITERM2_ST}"
    fi
    ;;
  -w) _iterm2_write "${_ITERM2_OSC}9;4;4;%d${_ITERM2_ST}" "${2:-0}" ;;
  -c) _iterm2_write "${_ITERM2_OSC}9;4;0${_ITERM2_ST}" ;;
  *) _iterm2_write "${_ITERM2_OSC}9;4;1;%d${_ITERM2_ST}" "${1:-0}" ;;
  esac
}

iterm2_badge() {
  _iterm2_active || return 0
  _iterm2_osc
  _ITERM2_TEXT=""
  if [ "${1:-}" != "-c" ]; then
    _ITERM2_TEXT="${*}"
  fi
  _iterm2_write "${_ITERM2_OSC}1337;SetBadgeFormat=%s${_ITERM2_ST}" "$(printf '%s' "${_ITERM2_TEXT}" | base64)"
}

iterm2_notify() {
  _iterm2_active || return 0
  _iterm2_osc
  _iterm2_write "${_ITERM2_OSC}9;%s${_ITERM2_ST}" "${*}"
}
