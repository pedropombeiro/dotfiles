#!/usr/bin/env bash

if [[ -d "${GDK_ROOT}" ]]; then
  function rebase-all() {
    CURRENT_BRANCH="$(git branch --show-current)"

    if ! git diff-index --quiet HEAD --; then
      echo 'Please stash the changes in the current branch before calling rebase-all!'
      return
    fi

    DEFAULT_BRANCH='main'
    git show-ref refs/remotes/origin/master >/dev/null && DEFAULT_BRANCH='master'
    git for-each-ref --shell --format='git switch %(refname) && git rebase '"${DEFAULT_BRANCH}"' && echo -------- && '\\'' refs/heads/pedropombeiro | { sed 's;refs/heads/;;'; echo "git switch '${CURRENT_BRANCH}'"; } | bash
  }

  function fgdku() {
    cd "${GDK_ROOT}/gitlab" || exit

    if ! git diff-index --quiet HEAD --; then
      echo 'Please stash the changes in the current branch before calling fgdku!'
      cd - >/dev/null
      return
    fi

    set -e
    echo "Updating GDK..."
    gdk update
    echo "Running simple test..."
    bin/rspec spec/lib/expand_variables_spec.rb
    echo "Rebasing local branches..."
    rebase-all
    echo "Done."

    set +e

    cd - >/dev/null
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
