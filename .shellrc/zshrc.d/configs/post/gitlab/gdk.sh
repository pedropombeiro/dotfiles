#!/usr/bin/env bash

if [[ -d ${GDK_ROOT} ]]; then
  autoload bashcompinit
  bashcompinit

  source "${GDK_ROOT}/support/completions/gdk.bash"

  alias fgdku='cd ${GDK_ROOT}/gitlab && gdk update && rebase-all && bin/rspec spec/lib/expand_variables_spec.rb'
  alias test-mr='bin/rspec $(git log master.. --oneline --name-only --pretty="format:" --diff-filter=CRAM | grep "spec/")'
fi

command -v direnv >/dev/null && eval "$(direnv hook zsh)"
