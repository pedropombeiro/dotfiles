#!/usr/bin/env zsh
#
# Validate the result of `yadm alt` for the current machine identity. CI runs
# this in a scratch HOME once per class so broken templates and alternates show
# up before they reach a machine.
#
# For every tracked alternate, the script works out which alternates apply to
# this identity (class, os, distro), then checks:
#   - an applicable alternate produced its target: a symlink to an applicable
#     non-template alternate, or a regular file rendered from an applicable
#     template
#   - no target links to an alternate that doesn't apply
#   - no broken untracked symlinks in directories that hold tracked files
#   - rendered templates contain no leftover `{{` or `{%` markers
#   - rendered `.json` parses with jq and rendered `.lua` compiles with luac
#
# It implements only the yadm conditions this repository uses. An unknown
# condition is reported as an error instead of being guessed at.

YADM_SCRIPTS=$( cd -- "$( dirname -- ${(%):-%x} )" &>/dev/null && pwd )

source "${YADM_SCRIPTS}/colors.sh"

# Query the repo with plain git: `yadm config local.*` and git passthrough
# commands trigger auto-alt, which would re-render the files under test.
repo=$(yadm introspect repo)
ygit() { git -C "${HOME}" --git-dir="${repo}" --work-tree="${HOME}" "$@"; }

# Identity, with the same fallbacks yadm uses when local.* isn't set
local id_class=$(ygit config local.class)
local id_os=$(ygit config local.os)
[[ -n ${id_os} ]] || id_os=$(uname -s)
local id_distro=$(ygit config local.distro)
if [[ -z ${id_distro} ]]; then
  if command -v lsb_release >/dev/null 2>&1; then
    id_distro=$(lsb_release -si 2>/dev/null)
  elif [[ -r /etc/os-release ]]; then
    id_distro=$(sed -n 's/^ID=//p' /etc/os-release | tr -d '"')
  fi
fi

local -a tracked=( "${(@f)$(ygit ls-files)}" )
local -a dirs=( "${(@u)tracked:h}" )
local -a errors=()

# Prints "applies" or "skip" for a condition list such as `os.Darwin,class.Work`,
# and "unknown:<condition>" for a condition this script doesn't implement.
conditions_apply() {
  local condition key value
  for condition in "${(@s:,:)1}"; do
    key=${condition%%.*}
    value=${condition#*.}
    [[ ${condition} == *.* ]] || value=""
    case ${key} in
      default | t | template | e | extension) ;;
      c | class) [[ ${value} == "${id_class}" ]] || { print skip; return; } ;;
      o | os) [[ ${(L)value} == "${(L)id_os}" ]] || { print skip; return; } ;;
      d | distro) [[ -n ${id_distro} && ${(L)value} == "${(L)id_distro}" ]] || { print skip; return; } ;;
      *) print "unknown:${condition}"; return ;;
    esac
  done
  print applies
}

is_template() { [[ ,$1, =~ ',(t|template)(\.[^,]*)?,' ]]; }

# Group tracked alternates by target path
typeset -A alternates
local file
for file in ${(M)tracked:#*\#\#*}; do
  alternates[${file%%\#\#*}]+="${file#*\#\#}"$'\n'
done

local target conditions result path_ link linked dir template
local -a applicable applicable_templates non_applicable
for target in ${(k)alternates}; do
  applicable=()
  applicable_templates=()
  non_applicable=()
  for conditions in "${(@f)${alternates[${target}]%$'\n'}}"; do
    result=$(conditions_apply "${conditions}")
    case ${result} in
      applies)
        if is_template "${conditions}"; then
          applicable_templates+=("${target}##${conditions}")
        else
          applicable+=("${target}##${conditions}")
        fi
        ;;
      skip) non_applicable+=("${target}##${conditions}") ;;
      *) errors+=("unsupported condition ${result#unknown:} in ${target}##${conditions}") ;;
    esac
  done

  path_="${HOME}/${target}"
  if [[ -L ${path_} ]]; then
    link=$(readlink "${path_}")
    linked="${target:h}/${link:t}"
    [[ ${target:h} == . ]] && linked=${link:t}
    if (( ${non_applicable[(Ie)${linked}]} )); then
      errors+=("${target} links to ${link:t}, which doesn't apply")
    elif (( ! ${applicable[(Ie)${linked}]} )); then
      errors+=("${target} links to ${link}, which isn't an applicable alternate")
    fi
  elif [[ -f ${path_} ]]; then
    if (( ${#applicable_templates} == 0 )); then
      (( ${#applicable} > 0 )) && errors+=("${target} is a regular file, expected a link to ${applicable[1]:t}")
    fi
  elif (( ${#applicable} + ${#applicable_templates} > 0 )); then
    local -a expected=( ${applicable[@]:t} ${applicable_templates[@]:t} )
    errors+=("${target} is missing; applicable: ${(j:, :)expected}")
  fi
done

for dir in "${dirs[@]}"; do
  # N = nullglob, D = include dotfiles, -@ = broken symlinks
  for link in "${HOME}/${dir}"/*(ND-@); do
    # Tracked symlinks (like skills.work/caproni) point into repos that only
    # some machines clone; only links that yadm alt creates must resolve.
    (( ${tracked[(Ie)${link#${HOME}/}]} )) && continue
    errors+=("broken symlink: ${link#${HOME}/} -> $(readlink "${link}")")
  done
done

for template in ${(M)tracked:#*\#\#*}; do
  is_template "${template#*\#\#}" || continue
  [[ $(conditions_apply "${template#*\#\#}") == applies ]] || continue
  target="${HOME}/${template%%\#\#*}"
  [[ -f ${target} && ! -L ${target} ]] || continue # reported above
  if grep -qE '\{\{|\{%' "${target}"; then
    errors+=("leftover template markers: ${target#${HOME}/}")
  fi
  case ${target} in
    *.json)
      jq empty "${target}" 2>/dev/null || errors+=("invalid JSON: ${target#${HOME}/}")
      ;;
    *.lua)
      luac -p "${target}" 2>/dev/null || errors+=("invalid Lua: ${target#${HOME}/}")
      ;;
  esac
done

local identity="class=${id_class} os=${id_os} distro=${id_distro}"
if (( ${#errors} > 0 )); then
  printf "${RED}%s${NC}\n" "Rendered alternates failed for ${identity}:"
  printf '  %s\n' "${(@u)errors}"
  exit 1
fi

printf "${GREEN}%s${NC}\n" "Rendered alternates OK for ${identity} (${#alternates} alternate targets)."
