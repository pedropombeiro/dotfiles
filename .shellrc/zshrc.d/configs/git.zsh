#!/usr/bin/env zsh

plugins+=(git git-extras)

export GIT_COMPLETION_CHECKOUT_NO_GUESS=1 # only autocomplete with local branches

if [[ -n ${HOMEBREW_PREFIX} ]]; then
  PATH="${PATH}:${HOMEBREW_PREFIX}/opt/git/share/git-core/contrib/git-jump"
  export PATH
fi

export GIT_EDITOR="nvim -c 'Trouble quickfix'" # Open 'git jump' results directly in quickfix window
