#!/usr/bin/env zsh

zsh-defer source "$ZSH/plugins/git/git.plugin.zsh"
zsh-defer source "$ZSH/plugins/git/git-extras.plugin.zsh"

export GIT_COMPLETION_CHECKOUT_NO_GUESS=1 # only autocomplete with local branches

if [[ -n ${HOMEBREW_PREFIX} ]]; then
  PATH="${PATH}:${HOMEBREW_PREFIX}/opt/git/share/git-core/contrib/git-jump"
  export PATH
fi
