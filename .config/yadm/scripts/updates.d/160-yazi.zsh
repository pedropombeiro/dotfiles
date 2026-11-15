#!/usr/bin/env zsh

step_yazi() {
  # Restore tracked configuration before upgrading plugins.
  # Remove package-managed payloads only; preserve tracked local adapters.
  local entry
  for entry in ~/.config/yazi/{plugins,flavors}/*(N); do
    [[ -n $(yadm ls-files -- "$entry") ]] || rm -rf -- "$entry"
  done
  yadm checkout -- ~/.config/yazi/
  ya pkg upgrade
  "${HOME}/.local/bin/dotfiles-theme" apply
}

_update_watch yazi
_update_register "yazi plugins" step_yazi
