#!/usr/bin/env zsh
# Step runner and change summary for the update scripts.
#
# `_step <label> <function>` runs one update step with its output captured in a
# per-run log. On a terminal, a spinner shows the running step, and one result
# line replaces it when the step ends. A failed step prints the end of its
# output and the run continues; `_update_finish` exits non-zero if any step
# failed. Steps report details with `_update_warn` (repeated in the final
# summary) and `_update_note` (appended to the result line). Child scripts can
# explain a failure by appending lines to the file named by
# `$UPDATE_FAILURE_FILE`; the final summary lists them under the failed step.
#
# Step functions run with ERR_RETURN, so the first failing command fails the
# step. Use `return`, not `exit`, inside a step: it runs in the main shell.
#
# The step total comes from counting lines that start with `_step ` in the files
# passed to `_update_init`, so call `_step` unconditionally at the start of a
# line and put any condition inside the step function.

zmodload zsh/datetime zsh/zselect

source "${YADM_SCRIPTS}/colors.sh"
DIM='\033[2m'

fpath=(~/.shellrc/zshrc.d/functions $fpath)
autoload -Uz iterm2_progress iterm2_badge iterm2_notify

typeset -g _ui_log_dir="${XDG_STATE_HOME:-${HOME}/.local/state}/dotfiles-update"
typeset -g UPDATE_LOG=''
typeset -g _ui_snapshot_dir='' _ui_notify_message=''
typeset -gF _ui_started_at=${EPOCHREALTIME}
typeset -gi _ui_total=0 _ui_current=0 _ui_tty=0 _ui_cleanup_done=0
typeset -gi _ui_spinner_pid=0 _ui_sudo_pid=0
typeset -gi _ui_progress_offset=${PROGRESS_OFFSET:-0} _ui_progress_range=${PROGRESS_RANGE:-100}
typeset -ga _ui_managers=() _ui_failures=() _ui_failure_details=() _ui_warnings=()
typeset -ga _ui_step_warnings=() _ui_step_notes=()
typeset -ga _ui_upgraded=() _ui_installed=() _ui_removed=() _ui_caveats=()
typeset -gi _ui_label_width=22
if [[ -t 1 ]]; then
  _ui_tty=1
else
  YELLOW='' GREEN='' RED='' CYAN='' BOLD='' NC='' DIM=''
fi

# Sets up the log, traps, and progress. Arguments are the files that contain
# this run's `_step` calls.
_update_init() {
  local file count

  for file in "$@"; do
    count=$(grep -c '^[[:space:]]*_step ' "${file}" 2>/dev/null)
    (( _ui_total += ${count:-0} ))
  done

  mkdir -p "${_ui_log_dir}"
  UPDATE_LOG="${_ui_log_dir}/$(date +%Y-%m-%dT%H-%M-%S).log"
  print -r -- "dotfiles update on ${HOST} at $(date)" >| "${UPDATE_LOG}"
  # Keep the 20 most recent logs.
  rm -f -- "${_ui_log_dir}"/*.log(Nom[21,-1])

  _ui_snapshot_dir=$(mktemp -d)

  trap _ui_cleanup EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  trap 'exit 129' HUP

  iterm2_badge "update: starting"
  if [[ -z "${PROGRESS_OFFSET+x}" ]]; then
    iterm2_progress -i
  else
    iterm2_progress "${_ui_progress_offset}"
  fi

  (( _ui_tty )) && printf '\e[?25l'
  printf "${DIM}%s${NC}\n" "Log: ${UPDATE_LOG/#${HOME}/~}"
}

# Asks for the sudo password up front and keeps the credentials fresh, so no
# step stops at a password prompt hidden behind the spinner.
_update_require_sudo() {
  (( $+commands[sudo] )) || return 0
  if [[ -t 0 ]]; then
    sudo -v || exit 1
  elif ! sudo -n -v 2>/dev/null; then
    printf "${YELLOW}%s${NC}\n" "No terminal for the sudo prompt; steps that need sudo may fail."
    return 0
  fi

  {
    trap - INT TERM HUP EXIT
    while kill -0 $$ 2>/dev/null; do
      sudo -n -v 2>/dev/null
      zselect -t 3000
    done
  } &
  _ui_sudo_pid=$!
}

# Records installed versions for the given managers so `_update_finish` can
# report what changed. Supported: brew, cask, mise, npm, mas, apt, opkg, nvim
# (Lazy plugin commits), and mason.
_update_track() {
  local manager

  for manager in "$@"; do
    (( $+functions[_ui_versions_${manager}] )) && _ui_managers+=("${manager}")
  done

  _ui_spinner_start '' 'Recording installed versions'
  _ui_snapshot before
  _ui_spinner_stop
}

_step() {
  local interactive=0
  if [[ $1 == --interactive ]]; then
    interactive=1
    shift
  fi
  local label=$1 fn=$2
  local prefix step_log line icon color
  local -x UPDATE_FAILURE_FILE
  local -i rc=0 shown hidden
  local -F start=${EPOCHREALTIME} elapsed

  _ui_current+=1
  prefix="[${_ui_current}/${_ui_total}]"
  _ui_step_warnings=()
  _ui_step_notes=()
  UPDATE_FAILURE_FILE=$(mktemp)
  iterm2_progress $(( _ui_progress_offset + (_ui_current - 1) * _ui_progress_range / (_ui_total > 0 ? _ui_total : 1) ))
  iterm2_badge "update: ${label}"
  print -r -- $'\n'"==> ${prefix} ${label}" >> "${UPDATE_LOG}"

  if (( interactive )); then
    printf "${BOLD}▶ %s %s${NC}\n" "${prefix}" "${label}"
    _ui_run "${fn}" || rc=$?
  else
    step_log=$(mktemp)
    _ui_spinner_start "${prefix}" "${label}"
    _ui_run "${fn}" >"${step_log}" 2>&1 </dev/null || rc=$?
    _ui_spinner_stop
    cat "${step_log}" >> "${UPDATE_LOG}"
  fi

  elapsed=$(( EPOCHREALTIME - start ))
  if (( rc )); then
    icon='✗' color=${RED}
    _ui_failures+=("${label} (exit ${rc})")
    _ui_failure_details+=("$(<"${UPDATE_FAILURE_FILE}")")
    print -r -- "==> failed with exit status ${rc}" >> "${UPDATE_LOG}"
  elif (( ${#_ui_step_warnings} )); then
    icon='!' color=${YELLOW}
  else
    icon='✓' color=${GREEN}
  fi

  printf "${color}%s${NC} %-8s %-*s ${DIM}%6.1fs${NC}" \
    "${icon}" "${prefix}" ${_ui_label_width} "${label}" ${elapsed}
  (( ${#_ui_step_notes} )) && printf "  ${DIM}%s${NC}" "${(j:; :)_ui_step_notes}"
  printf '\n'

  for line in "${_ui_step_warnings[@]}"; do
    printf "  ${YELLOW}%s${NC}\n" "${line}"
    _ui_warnings+=("${label}: ${line}")
  done

  if (( rc )) && [[ -n ${step_log} ]]; then
    shown=60
    hidden=$(( $(wc -l < "${step_log}") - shown ))
    (( hidden > 0 )) && printf "    ${DIM}… %d earlier lines in the log${NC}\n" ${hidden}
    tail -n ${shown} "${step_log}" | sed 's/^/    /'
  fi

  [[ -n ${step_log} ]] && rm -f "${step_log}"
  rm -f "${UPDATE_FAILURE_FILE}"
  return 0
}

# Shows a message under the step's result line and in the final summary.
_update_warn() {
  _ui_step_warnings+=("$*")
  print -r -- "warning: $*"
}

# Appends a short detail to the step's result line.
_update_note() {
  _ui_step_notes+=("$*")
  print -r -- "note: $*"
}

# Prints the summary and exits: non-zero if any step failed.
_update_finish() {
  local manager

  _ui_spinner_start '' 'Summarizing changes'
  _ui_snapshot after
  for manager in "${_ui_managers[@]}"; do
    _ui_diff "${manager}"
  done
  _ui_collect_caveats
  _ui_spinner_stop

  _ui_print_summary

  if (( ${#_ui_failures} )); then
    _ui_notify_message="update failed: ${#_ui_failures} step(s)"
    exit 1
  fi
  local -i changes=$(( ${#_ui_upgraded} + ${#_ui_installed} + ${#_ui_removed} ))
  _ui_notify_message="update complete: ${changes} change(s)"
  exit 0
}

_ui_run() {
  setopt local_options err_return
  "$@"
}

_ui_spinner_start() {
  local prefix=$1 label=$2

  if (( ! _ui_tty )); then
    printf '▶ %s %s\n' "${prefix:-}" "${label}"
    return 0
  fi

  {
    trap - INT TERM HUP EXIT
    local -a frames=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
    local -i i=0
    local -F spinner_start=${EPOCHREALTIME}
    while true; do
      printf "\r\e[K${CYAN}%s${NC} %-8s %-*s ${DIM}%6.0fs${NC}" \
        "${frames[i % ${#frames} + 1]}" "${prefix}" ${_ui_label_width} "${label}" \
        $(( EPOCHREALTIME - spinner_start ))
      i+=1
      zselect -t 10
    done
  } &
  _ui_spinner_pid=$!
}

_ui_spinner_stop() {
  (( _ui_spinner_pid )) || return 0
  kill ${_ui_spinner_pid} 2>/dev/null
  wait ${_ui_spinner_pid} 2>/dev/null
  _ui_spinner_pid=0
  printf '\r\e[K'
}

_ui_cleanup() {
  local rc=$?
  (( _ui_cleanup_done )) && return ${rc}
  _ui_cleanup_done=1

  _ui_spinner_stop
  (( _ui_sudo_pid )) && kill ${_ui_sudo_pid} 2>/dev/null
  (( _ui_tty )) && printf '\e[?25h'
  [[ -n ${_ui_snapshot_dir} ]] && rm -rf "${_ui_snapshot_dir}"

  if (( rc )); then
    iterm2_progress -e
    iterm2_badge "update: FAILED"
    iterm2_notify "${_ui_notify_message:-update failed}"
  elif [[ -z "${PROGRESS_OFFSET+x}" ]]; then
    iterm2_progress 100
    iterm2_badge -c
    iterm2_progress -c
    iterm2_notify "${_ui_notify_message:-update complete}"
  fi
  return ${rc}
}

# ── Version snapshots ─────────────────────────────────────────────────
# Each prints one `name<TAB>version` line per installed package.

# `brew list --cask --versions` aborts on the first cask with broken metadata,
# so read both lists from `brew info`, once per snapshot.
_ui_brew_info() {
  local cache="${_ui_snapshot_dir}/brew-info-${_ui_phase}.json"
  (( $+commands[brew] )) || return 1
  [[ -s ${cache} ]] || brew info --json=v2 --installed >| "${cache}" || return 1
  jq -r "$1" "${cache}"
}

_ui_versions_brew() {
  _ui_brew_info '.formulae[] | "\(.name)\t\(.installed[-1].version)"'
}

_ui_versions_cask() {
  _ui_brew_info '.casks[] | "\(.token)\t\(.installed)"'
}

_ui_versions_mise() {
  (( $+commands[mise] )) || return 1
  (cd ~ && mise ls --current --json) |
    jq -r 'to_entries[] | "\(.key)\t\([.value[].version] | join(", "))"'
}

_ui_versions_npm() {
  (( $+commands[npm] )) || return 1
  npm ls -g --json --depth=0 |
    jq -r '.dependencies // {} | to_entries[] | "\(.key)\t\(.value.version)"'
}

_ui_versions_mas() {
  (( $+commands[mas] )) || return 1
  mas list | sed -E 's/^ *[0-9]+ +(.*[^ ]) +\((.*)\)$/\1\t\2/'
}

# Lazy plugins report a short commit; `_ui_detail_nvim` adds the commit count.
_ui_versions_nvim() {
  local lockfile="${XDG_CONFIG_HOME:-${HOME}/.config}/nvim/lazy-lock.json"
  [[ -f ${lockfile} ]] || return 1
  jq -r 'to_entries[] | "\(.key)\t\(.value.commit[0:7])"' "${lockfile}"
}

# Prints " (N commits)" for a plugin that moved forward, or " (rolled back)".
_ui_detail_nvim() {
  local dir="${XDG_DATA_HOME:-${HOME}/.local/share}/nvim/lazy/$1" count
  [[ -d ${dir} ]] || return 0
  count=$(git -C "${dir}" rev-list --count "$2..$3" 2>/dev/null) || return 0
  if (( count > 0 )); then
    printf ' (%d commit%s)' ${count} "${${count:#1}:+s}"
  elif git -C "${dir}" merge-base --is-ancestor "$3" "$2" 2>/dev/null; then
    printf ' (rolled back)'
  fi
}

_ui_versions_mason() {
  local -a receipts=("${XDG_DATA_HOME:-${HOME}/.local/share}"/nvim/mason/packages/*/mason-receipt.json(N))
  (( ${#receipts} )) || return 1
  jq -r '"\(.name)\t\(.source.id | sub(".*@"; ""))"' "${receipts[@]}"
}

_ui_versions_apt() {
  (( $+commands[dpkg-query] )) || return 1
  dpkg-query -W -f '${Package}\t${Version}\n'
}

_ui_versions_opkg() {
  (( $+commands[opkg] )) || return 1
  opkg list-installed | awk -F ' - ' -v OFS='\t' '{ print $1, $2 }'
}

_ui_snapshot() {
  local _ui_phase=$1 manager

  mkdir -p "${_ui_snapshot_dir}/${_ui_phase}"
  for manager in "${_ui_managers[@]}"; do
    "_ui_versions_${manager}" >| "${_ui_snapshot_dir}/${_ui_phase}/${manager}" 2>/dev/null ||
      rm -f "${_ui_snapshot_dir}/${_ui_phase}/${manager}"
  done
}

_ui_diff() {
  local manager=$1 name version
  local before="${_ui_snapshot_dir}/before/${manager}" after="${_ui_snapshot_dir}/after/${manager}"
  local -A old new

  # Skip a manager whose listing failed, rather than reporting every package.
  [[ -s ${before} && -s ${after} ]] || return 0

  while IFS=$'\t' read -r name version; do
    [[ -n ${name} ]] && old[${name}]=${version}
  done < "${before}"
  while IFS=$'\t' read -r name version; do
    [[ -n ${name} ]] && new[${name}]=${version}
  done < "${after}"

  for name in ${(ko)new}; do
    if (( ! ${+old[${name}]} )); then
      _ui_installed+=("${manager}"$'\t'"${name}"$'\t'"${new[${name}]}")
    elif [[ ${old[${name}]} != "${new[${name}]}" ]]; then
      version="${old[${name}]} → ${new[${name}]}"
      if (( $+functions[_ui_detail_${manager}] )); then
        version+=$("_ui_detail_${manager}" "${name}" "${old[${name}]}" "${new[${name}]}" 2>/dev/null)
      fi
      _ui_upgraded+=("${manager}"$'\t'"${name}"$'\t'"${version}")
    fi
  done
  for name in ${(ko)old}; do
    (( ${+new[${name}]} )) || _ui_removed+=("${manager}"$'\t'"${name}"$'\t'"${old[${name}]}")
  done
}

# Collects Homebrew caveats for upgraded and installed formulae and casks.
_ui_collect_caveats() {
  local row manager output
  local -a formulae casks records
  local -i i

  for row in "${_ui_upgraded[@]}" "${_ui_installed[@]}"; do
    manager=${row%%$'\t'*}
    row=${row#*$'\t'}
    case ${manager} in
      brew) formulae+=("${row%%$'\t'*}") ;;
      cask) casks+=("${row%%$'\t'*}") ;;
    esac
  done

  if (( ${#formulae} )); then
    output=$(brew info --json=v2 --formula "${formulae[@]}" 2>/dev/null |
      jq -j '.formulae[] | select((.caveats // "") != "") | .name, "\u0000", .caveats, "\u0000"')
    records+=("${(@0)output}")
  fi
  if (( ${#casks} )); then
    output=$(brew info --json=v2 --cask "${casks[@]}" 2>/dev/null |
      jq -j '.casks[] | select((.caveats // "") != "") | .token, "\u0000", .caveats, "\u0000"')
    records+=("${(@0)output}")
  fi

  records=("${(@)records:#}")
  for (( i = 1; i < ${#records}; i += 2 )); do
    _ui_caveats+=("${records[i]}"$'\t'"${records[i + 1]%$'\n'}")
  done
}

# Prints to the terminal (with color) and to the log (without).
_ui_emit() {
  local color=$1 text=$2
  printf "${color}%s${NC}\n" "${text}"
  print -r -- "${text}" >> "${UPDATE_LOG}"
}

_ui_section() {
  _ui_emit '' ''
  _ui_emit "${BOLD}" "━━ $1 ━━"
}

_ui_rows() {
  local row manager name rest
  local -i width=0

  for row in "$@"; do
    name=${${row#*$'\t'}%%$'\t'*}
    (( ${#name} > width )) && width=${#name}
  done
  (( width > 32 )) && width=32

  for row in "$@"; do
    manager=${row%%$'\t'*}
    rest=${row#*$'\t'}
    name=${rest%%$'\t'*}
    _ui_emit '' "$(printf '%-6s %-*s %s' "${manager}" ${width} "${name}" "${rest#*$'\t'}")"
  done
}

_ui_print_summary() {
  local row line
  local -i elapsed=$(( EPOCHREALTIME - _ui_started_at ))

  (( ${#_ui_upgraded} )) && { _ui_section 'Upgraded'; _ui_rows "${_ui_upgraded[@]}" }
  (( ${#_ui_installed} )) && { _ui_section 'Installed'; _ui_rows "${_ui_installed[@]}" }
  (( ${#_ui_removed} )) && { _ui_section 'Removed'; _ui_rows "${_ui_removed[@]}" }

  if (( ${#_ui_warnings} + ${#_ui_caveats} )); then
    _ui_section 'Warnings'
    for line in "${_ui_warnings[@]}"; do
      _ui_emit "${YELLOW}" "! ${line}"
    done
    for row in "${_ui_caveats[@]}"; do
      _ui_emit "${YELLOW}" "! ${row%%$'\t'*} caveats:"
      for line in "${(@f)${row#*$'\t'}}"; do
        _ui_emit '' "    ${line}"
      done
    done
  fi

  if (( ${#_ui_failures} )); then
    _ui_section 'Failed'
    local -i i
    for i in {1..${#_ui_failures}}; do
      _ui_emit "${RED}" "✗ ${_ui_failures[i]}"
      for line in "${(@f)_ui_failure_details[i]}"; do
        [[ -n ${line} ]] && _ui_emit "${RED}" "    ${line}"
      done
    done
  fi

  _ui_emit '' ''
  if (( ${#_ui_upgraded} + ${#_ui_installed} + ${#_ui_removed} == 0 && ${#_ui_managers} )); then
    _ui_emit "${GREEN}" "No package changes."
  fi
  _ui_emit "${DIM}" "Finished in $(( elapsed / 60 ))m$(( elapsed % 60 ))s. Log: ${UPDATE_LOG/#${HOME}/~}"
}
