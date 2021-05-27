#!/usr/bin/env bash

if [[ -d "${GDK_ROOT}" ]]; then
  function rebase-all() {
    CURRENT_BRANCH="$(git branch --show-current)"

    if git diff-index --quiet HEAD --; then
      STASHED=0
    else
      git stash
      STASHED=1
    fi

    set -e -o pipefail

    git for-each-ref --shell --format='git switch %(refname) && git rebase master && echo --------' refs/heads/pedropombeiro | sed 's;refs/heads/;;' | bash

    set +e

    git checkout "${CURRENT_BRANCH}"
    [[ ${STASHED} -eq 1 ]] &&  git stash pop
  }
fi
