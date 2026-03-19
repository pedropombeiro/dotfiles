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

  # Re-prepend shims to PATH: macOS path_helper (/etc/zprofile) reorders PATH
  # after .zshenv, pushing shims behind /usr/bin. This ensures mise shims take
  # precedence over system binaries like /usr/bin/rake (Ruby 2.6).
  # typeset -gU deduplicates the path array (first occurrence wins).
  # -g is required because this file is sourced inside a function chain
  # (source_files → _load_settings); without it, typeset creates a local shadow.
  typeset -gU path
  path=("${HOME}/.local/share/mise/shims" "${HOME}/.local/bin" $path)
fi
