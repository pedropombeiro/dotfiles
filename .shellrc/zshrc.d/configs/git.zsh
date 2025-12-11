#!/usr/bin/env zsh

# Load git aliases immediately so they're available right away
# compdef is now available because we autoload compinit early
source "$ZSH/plugins/git/git.plugin.zsh"
# Git extras can be deferred (less commonly used)
zsh-defer source "$ZSH/plugins/git/git-extras.plugin.zsh"

export GIT_COMPLETION_CHECKOUT_NO_GUESS=1 # only autocomplete with local branches

if [[ -n ${HOMEBREW_PREFIX} ]]; then
  PATH="${PATH}:${HOMEBREW_PREFIX}/opt/git/share/git-core/contrib/git-jump"
  export PATH
fi
