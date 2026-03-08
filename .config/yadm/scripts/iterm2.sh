#!/usr/bin/env bash

# shellcheck disable=SC2059

_iterm2_tty="${ITERM2_TTY:-/dev/tty}"

_iterm2_active() {
  [[ "${TERM_PROGRAM}" == "iTerm.app" || "${LC_TERMINAL}" == "iTerm2" || -n "${ITERM_SESSION_ID}" ]]
}

_iterm2_osc() {
  if [[ -n "${TMUX}" ]]; then
    _osc="\ePtmux;\e\e]"
    _st="\a\e\\"
  else
    _osc="\e]"
    _st="\a"
  fi
}

iterm2_progress() {
  _iterm2_active || return 0
  local _osc _st
  _iterm2_osc
  {
    case "${1}" in
      -i) printf "${_osc}9;4;3${_st}" ;;
      -e) if [[ -n "${2}" ]]; then printf "${_osc}9;4;2;%d${_st}" "${2}"; else printf "${_osc}9;4;2${_st}"; fi ;;
      -w) printf "${_osc}9;4;4;%d${_st}" "${2}" ;;
      -c) printf "${_osc}9;4;0${_st}" ;;
      *)  printf "${_osc}9;4;1;%d${_st}" "${1}" ;;
    esac
  } >"${_iterm2_tty}" 2>/dev/null || true
}

iterm2_badge() {
  _iterm2_active || return 0
  local _osc _st
  _iterm2_osc
  local text=""
  [[ "${1}" != "-c" ]] && text="${*}"
  printf "${_osc}1337;SetBadgeFormat=%s${_st}" "$(printf '%s' "${text}" | base64)" >"${_iterm2_tty}" 2>/dev/null || true
}

iterm2_notify() {
  _iterm2_active || return 0
  local _osc _st
  _iterm2_osc
  printf "${_osc}9;%s${_st}" "${*}" >"${_iterm2_tty}" 2>/dev/null || true
}
