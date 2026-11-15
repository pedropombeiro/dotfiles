#!/usr/bin/env zsh

step_bat() {
  "${HOME}/.local/bin/dotfiles-theme" install
  "${HOME}/.local/bin/dotfiles-theme" apply
}

_update_register "bat theme" step_bat
