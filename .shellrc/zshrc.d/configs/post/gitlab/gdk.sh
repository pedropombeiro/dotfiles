#!/usr/bin/env bash

if [[ -d ${GDK_ROOT} ]]; then
  autoload bashcompinit
  bashcompinit

  source "${GDK_ROOT}/support/completions/gdk.bash"

  alias be="bundle exec "
  alias compile_docs="bundle exec rake gitlab:graphql:compile_docs"
  alias guard="SPRING=1 bundle exec guard"
  alias test-mr='bin/rspec $(git log master.. --oneline --name-only --pretty="format:" --diff-filter=CRAM | grep "spec/")'
fi

command -v direnv >/dev/null && eval "$(direnv hook zsh)"
