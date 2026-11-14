#!/usr/bin/env zsh

# Each version adapter prints name<TAB>version lines.
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

# Prints name<TAB>short HEAD commit when the directory is a git checkout.
_ui_git_head() {
  local name=$1 dir=$2 commit
  [[ -e ${dir}/.git ]] || return 0
  commit=$(git -C "${dir}" rev-parse --short=7 HEAD 2>/dev/null) || return 0
  print -r -- "${name}"$'\t'"${commit}"
}

# Describes how far a checkout moved between two commits.
_ui_git_distance() {
  local dir=$1 old=$2 new=$3 count
  [[ -d ${dir} ]] || return 0
  count=$(git -C "${dir}" rev-list --count "${old}..${new}" 2>/dev/null) || return 0
  if (( count > 0 )); then
    printf ' (%d commit%s)' ${count} "${${count:#1}:+s}"
  elif git -C "${dir}" merge-base --is-ancestor "${new}" "${old}" 2>/dev/null; then
    printf ' (rolled back)'
  fi
}

_ui_versions_nvim() {
  local lockfile="${XDG_CONFIG_HOME:-${HOME}/.config}/nvim/lazy-lock.json"
  [[ -f ${lockfile} ]] || return 1
  jq -r 'to_entries[] | "\(.key)\t\(.value.commit[0:7])"' "${lockfile}"
}

_ui_detail_nvim() {
  _ui_git_distance "${XDG_DATA_HOME:-${HOME}/.local/share}/nvim/lazy/$1" "$2" "$3"
}

typeset -g _ui_zinit_dir="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit"

# zinit stores owner/repo plugins as owner---repo directories.
_ui_zinit_path() {
  if [[ $1 == zinit ]]; then
    print -r -- "${_ui_zinit_dir}/zinit.git"
  else
    print -r -- "${_ui_zinit_dir}/plugins/${1//\//---}"
  fi
}

_ui_versions_zinit() {
  local dir
  [[ -d ${_ui_zinit_dir} ]] || return 1
  _ui_git_head zinit "${_ui_zinit_dir}/zinit.git"
  for dir in "${_ui_zinit_dir}"/plugins/*(N/); do
    _ui_git_head "${${dir:t}//---//}" "${dir}"
  done
}

_ui_detail_zinit() {
  _ui_git_distance "$(_ui_zinit_path "$1")" "$2" "$3"
}

_ui_versions_mason() {
  local -a receipts=("${XDG_DATA_HOME:-${HOME}/.local/share}"/nvim/mason/packages/*/mason-receipt.json(N))
  (( ${#receipts} )) || return 1
  jq -r '"\(.name)\t\(.source.id | sub(".*@"; ""))"' "${receipts[@]}"
}

typeset -g _ui_skill_lockfile="${HOME}/.agents/.skill-lock.json"

_ui_versions_skills() {
  [[ -f ${_ui_skill_lockfile} ]] || return 1
  jq -r '.skills | to_entries[] | "\(.key)\t\(.value.skillFolderHash[0:7])"' "${_ui_skill_lockfile}"
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
  # Failed or empty listings must not report every package as removed.
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
