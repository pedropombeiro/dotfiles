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
  # Resolve tools concurrently during startup without changing install/build jobs.
  # The anonymous function restores MISE_JOBS, including its unset state.
  () {
    local -x MISE_JOBS=${MISE_JOBS:-4}
    eval "$("$mise_bin" activate zsh)"
  }
  # Activation snapshots MISE_* for its first-prompt fast path. Record the
  # restored environment so the temporary jobs override does not force a refresh.
  if (($+functions[_mise_hook_env_state])); then
    export __MISE_ZSH_ACTIVATE_ENV="$(_mise_hook_env_state)"
  fi
fi
