#!/usr/bin/env zsh

# Graceful no-op when atuin is not yet installed (e.g. fresh system before `mise install`)
command -v atuin &>/dev/null || return

# Import native zsh history into atuin's SQLite DB on first run.
# Guarded by a sentinel file because `atuin import` is not idempotent (creates duplicates).
if [[ ! -f "${XDG_DATA_HOME:-$HOME/.local/share}/atuin/.imported" ]]; then
  atuin import auto 2>/dev/null
  mkdir -p "${XDG_DATA_HOME:-$HOME/.local/share}/atuin"
  touch "${XDG_DATA_HOME:-$HOME/.local/share}/atuin/.imported"
fi

# Cache `atuin init zsh` output to avoid ~30ms eval overhead on every shell startup.
# Regenerates when the atuin binary is newer (i.e. after upgrades).
_atuin_init="${XDG_DATA_HOME:-$HOME/.local/share}/atuin/init.zsh"

if [[ ! -f "$_atuin_init" || "$_atuin_init" -ot "$(command -v atuin)" ]]; then
  mkdir -p "${_atuin_init:h}"
  atuin init zsh >"$_atuin_init"
fi

# Deferred load (wait'0c') so atuin binds after fzf (wait'0b') and zsh-vi-mode
zinit wait'0c' lucid nocd light-mode for \
  atload"source $_atuin_init" \
  zdharma-continuum/null

unset _atuin_init
