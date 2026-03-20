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

  # macOS path_helper (/etc/zprofile) reorders PATH after .zshenv, pushing
  # shims behind /usr/bin. Re-prepend shims so they beat system binaries
  # (e.g. /usr/bin/rake from Ruby 2.6).
  # Then eagerly run hook-env so that concrete installs land *ahead* of shims.
  # This gives the correct priority (installs > shims > system) from the very
  # first command, including in subshells spawned by gdk update.
  # typeset -gU deduplicates the path array (first occurrence wins).
  # -g is required because this file is sourced inside a function chain
  # (source_files → _load_settings); without it, typeset creates a local shadow.
  typeset -gU path
  path=("${HOME}/.local/share/mise/shims" "${HOME}/.local/bin" $path)

  eval "$("$mise_bin" hook-env -s zsh 2>/dev/null)"
fi
