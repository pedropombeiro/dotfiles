#!/usr/bin/env zsh

step_zinit() {
  # zinit's own code expects failing commands not to abort it.
  setopt local_options no_err_return
  ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
  [[ -f "${ZINIT_HOME}/zinit.zsh" ]] || return 0
  # Include our custom completions when zinit rebuilds .zcompdump.
  fpath=($HOME/.config/zsh/site-functions $fpath)
  source "${ZINIT_HOME}/zinit.zsh" || return
  ZINIT[NO_PAGER]=1
  zinit self-update || return
  zinit update --parallel || return

  # An interrupted extraction can leave snippets with metadata but no payload.
  () {
    setopt local_options extended_glob
    local dir
    local -a stripped payload
    for dir in ${ZINIT[SNIPPETS_DIR]:-${HOME}/.local/share/zinit/snippets}/**/._zinit(N/); do
      dir="${dir:h}"
      payload=( ${dir}/*~*.zwc(.N) )
      (( ${#payload} )) || stripped+=("${dir:t}")
    done
    (( ${#stripped} )) || return 0
    _update_note "re-downloaded ${#stripped} snippet(s) with missing files: ${stripped[*]}"
    zinit update --reset --snippets
  } || return
}

step_zsh_bytecode() {
  local zinit_data="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit"
  local file
  local -a pending
  local -i i
  # Remove broken links and rebuild compiled shell files.
  rm -f ~/.shellrc/**/*(-@N)
  rm -f ~/*.zwc(N) ~/.*.zwc(N) ~/.shellrc/**/*.zwc(N) ${zinit_data}/**/*.zwc(N)
  # Login startup compiles Zinit files asynchronously; wait up to five seconds.
  zsh -il -c exit
  for (( i = 0; i < 50; i++ )); do
    pending=()
    for file in ${zinit_data}/**/*.zsh(.L+0N); do
      [[ -s ${file}.zwc ]] || pending+=("${file}")
    done
    (( ${#pending} )) || return 0
    zselect -t 10 || true
  done
  _update_warn "${#pending} zinit file(s) still had no .zwc after 5s; the next login shell compiles them."
}

_update_watch zinit
_update_register "zinit" step_zinit
_update_register "zsh bytecode" step_zsh_bytecode
