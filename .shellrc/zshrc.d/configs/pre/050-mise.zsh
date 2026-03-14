#!/usr/bin/env zsh

# $commands is zsh's hash of executables in $PATH (faster than `command -v`);
# fall back to the default install location for bootstrapping before mise is in PATH
local mise_bin="${commands[mise]:-${HOME}/.local/bin/mise}"
[[ -x "$mise_bin" ]] && eval "$("$mise_bin" activate zsh)"
