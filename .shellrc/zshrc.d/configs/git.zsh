#!/usr/bin/env zsh

# Load git plugins via zinit with turbo mode
zinit ice wait'0b' lucid atload'unalias gf gfa gpsup gswm 2>/dev/null'
zinit snippet OMZP::git

zinit ice wait'0c' lucid
zinit snippet OMZP::git-extras

export GIT_COMPLETION_CHECKOUT_NO_GUESS=1 # only autocomplete with local branches

if [[ -n ${HOMEBREW_PREFIX} ]]; then
  PATH="${PATH}:${HOMEBREW_PREFIX}/opt/git/share/git-core/contrib/git-jump"
  export PATH
fi
