#!/usr/bin/env zsh

# Activate after compinit so mise's tool completions do not initialize it again.
# Generate for this shell: activation embeds PATH and must not be cached across
# sessions. Its initial hook makes concrete installs available before the first
# command, and its precmd/chpwd hooks keep project environments up to date.
local mise_bin="${commands[mise]:-${HOME}/.local/bin/mise}"
if [[ -x "$mise_bin" ]]; then
  # A parent shell or tmux can pass concrete installs through PATH. Treat them
  # as mise-managed rather than original user paths, otherwise activation can
  # leave them behind shims or preserve an inactive project's tool version.
  path=(${path:#${MISE_DATA_DIR:-$HOME/.local/share/mise}/installs/*})
  export __MISE_ORIG_PATH="$PATH"
  eval "$("$mise_bin" activate zsh)"
fi
