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

    git for-each-ref --shell --format='git switch %(refname) && git rebase master && echo -------- && '\\'' refs/heads/pedropombeiro | { sed 's;refs/heads/;;'; echo 'echo Done'; } | bash

    git switch "${CURRENT_BRANCH}"
    [[ ${STASHED} -eq 1 ]] && git stash pop
  }

  function branch-to() {
    if command -v "$1" >/dev/null; then
      git log master.. --oneline --name-only --pretty="format:" --diff-filter=CRAM | xargs "$1"
    else
      echo "'$1' is not an executable. Please specify an editor such as 'code'." > /dev/stderr
      return 1
    fi
  }
fi
