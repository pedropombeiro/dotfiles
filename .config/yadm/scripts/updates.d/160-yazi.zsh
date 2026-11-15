#!/usr/bin/env zsh

step_yazi() {
  # Restore tracked configuration before upgrading plugins.
  rm -rf ~/.config/yazi/plugins/* ~/.config/yazi/flavors/*
  yadm checkout -- ~/.config/yazi/
  ya pkg upgrade
  "${HOME}/.local/bin/dotfiles-theme" apply
}

_update_watch yazi
_update_register "yazi plugins" step_yazi
