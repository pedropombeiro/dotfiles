#!/usr/bin/env zsh

# Load git plugin from oh-my-zsh via zinit
zinit snippet OMZP::git
zinit snippet OMZP::git-extras

export GIT_COMPLETION_CHECKOUT_NO_GUESS=1 # only autocomplete with local branches

if [[ -n ${HOMEBREW_PREFIX} ]]; then
  PATH="${PATH}:${HOMEBREW_PREFIX}/opt/git/share/git-core/contrib/git-jump"
  export PATH
fi
