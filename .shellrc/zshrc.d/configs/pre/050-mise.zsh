#!/usr/bin/env zsh

local mise_bin="${commands[mise]:-${HOME}/.local/bin/mise}"
[[ -x "$mise_bin" ]] && eval "$("$mise_bin" activate zsh)"
