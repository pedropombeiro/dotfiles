#!/usr/bin/env sh

link_duo_defaults() (
  duo_source="$HOME/Developer/gitlab.com/opencode.jsonc##class.Work"
  duo_target="$1/opencode.jsonc"
  [ -f "$duo_source" ] || return 1
  if [ -e "$duo_target" ] || [ -L "$duo_target" ]; then
    [ -L "$duo_target" ] && [ "$(readlink "$duo_target")" = "$duo_source" ] && return 0
    printf 'Existing OpenCode config left unchanged: %s\n' "$duo_target" >&2
    return 1
  fi
  ln -s "$duo_source" "$duo_target"
)
