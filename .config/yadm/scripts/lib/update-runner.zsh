#!/usr/bin/env zsh

# Modules only define functions and register work. The runner executes it later.
typeset -ga _update_labels=() _update_functions=() _update_interactive=()
typeset -ga _update_managers=() _update_repos=()
typeset -gi _update_sudo=0

_update_register() {
  local interactive=0
  if [[ $1 == --interactive ]]; then
    interactive=1
    shift
  fi
  if (( $# != 2 )) || [[ -z $1 || -z $2 ]]; then
    print -ru2 -- 'Usage: _update_register [--interactive] label function'
    return 1
  fi
  if (( ! $+functions[$2] )) || (( ${_update_functions[(Ie)$2]} )); then
    print -ru2 -- "Undefined or duplicate update function: $2"
    return 1
  fi
  _update_labels+=("$1")
  _update_functions+=("$2")
  _update_interactive+=("$interactive")
}

_update_use_sudo() {
  _update_sudo=1
}

_update_watch() {
  _update_managers+=("$@")
  _update_managers=("${(@u)_update_managers}")
}

# Reports commits that steps pull into these git checkouts.
_update_watch_repos() {
  _update_repos+=("$@")
  _update_repos=("${(@u)_update_repos}")
  _update_watch repos
}

_update_load_modules() {
  local modules_dir=$1 module
  local -a modules=("$modules_dir"/*.zsh(N))
  modules=("${(@)modules:#*\#\#*}")
  if (( ! ${#modules} )); then
    print -ru2 -- "No update modules found in ${modules_dir}; run yadm alt first"
    return 1
  fi
  # Validate every entry before sourcing any module or starting live work.
  for module in "${modules[@]}"; do
    if [[ ! -f $module || ! -r $module || ! -x $module ]]; then
      print -ru2 -- "Update module is not a readable executable file: ${module}"
      return 1
    fi
    zsh -n "$module" || return
  done
  for module in "${modules[@]}"; do
    # ERR_RETURN catches a failed registration even before the module's last line.
    _update_source_module "$module" || {
      print -ru2 -- "Could not load update module: ${module}"
      return 1
    }
  done
  if (( ! ${#_update_functions} )); then
    print -ru2 -- 'No update steps registered'
    return 1
  fi
}

_update_source_module() {
  setopt local_options err_return
  source "$1"
}

_update_execute() {
  local -i index
  _update_init "${#_update_functions}"
  if (( _update_sudo )); then
    _update_require_sudo
  fi
  _update_track "${_update_managers[@]}"
  for (( index = 1; index <= ${#_update_functions}; index++ )); do
    if (( _update_interactive[index] )); then
      _step --interactive "${_update_labels[index]}" "${_update_functions[index]}"
    else
      _step "${_update_labels[index]}" "${_update_functions[index]}"
    fi
  done
  _update_finish
}
