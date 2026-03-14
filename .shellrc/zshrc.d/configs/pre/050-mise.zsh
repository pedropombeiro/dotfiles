#!/usr/bin/env zsh

# $commands is zsh's hash of executables in $PATH (faster than `command -v`);
# fall back to the default install location for bootstrapping before mise is in PATH
local mise_bin="${commands[mise]:-${HOME}/.local/bin/mise}"
if [[ -x "$mise_bin" ]]; then
  local cache_dir="${XDG_CACHE_HOME:-${HOME}/.cache}/mise"
  local cache_file="${cache_dir}/activate.zsh"

  if [[ ! -f "$cache_file" || "$cache_file" -ot "$mise_bin" ]]; then
    mkdir -p "$cache_dir"
    "$mise_bin" activate zsh | sed '/^_mise_hook$/d' >| "$cache_file"
  fi

  source "$cache_file"
fi
