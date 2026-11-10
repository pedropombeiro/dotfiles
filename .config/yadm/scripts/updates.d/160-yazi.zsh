#!/usr/bin/env zsh

step_yazi() {
  # Restore tracked configuration before upgrading plugins.
  rm -rf ~/.config/yazi/plugins/* ~/.config/yazi/flavors/*
  yadm checkout -- ~/.config/yazi/
  ya pkg upgrade
}

_update_register "yazi plugins" step_yazi
