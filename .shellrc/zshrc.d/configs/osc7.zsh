#!/usr/bin/env zsh

# Emit OSC 7 (working directory notification) so tmux #{pane_path} preserves symlinks
autoload -Uz add-zsh-hook

_osc7_chpwd() {
  printf '\e]7;file://%s%s\e\\' "${HOST}" "${PWD}"
}

add-zsh-hook chpwd _osc7_chpwd
_osc7_chpwd
