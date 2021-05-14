#!/usr/bin/env bash

if [[ -d ${GDK_ROOT} ]]; then
  autoload bashcompinit
  bashcompinit

  source "${GDK_ROOT}/support/completions/gdk.bash"
fi

command -v direnv >/dev/null && eval "$(direnv hook zsh)"
