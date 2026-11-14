#!/usr/bin/env zsh

_update_watch tmux

step_tmux_plugins() {
  (( $+commands[tmux] )) || return 0
  local tpm_bin="${XDG_DATA_HOME:-${HOME}/.local/share}/tmux/plugins/tpm/bin"
  local config="${XDG_CONFIG_HOME:-${HOME}/.config}/tmux/tmux.conf"

  # Updating existing checkouts alone does not install newly configured plugins.
  "${tpm_bin}/install_plugins" || return $?
  "${tpm_bin}/update_plugins" all || return $?
  "${tpm_bin}/clean_plugins" || return $?

  # The CLI installer does not initialize plugins in an already running server.
  if tmux has-session 2>/dev/null; then
    tmux source-file "$config"
  fi
}

_update_register "tmux plugins" step_tmux_plugins
