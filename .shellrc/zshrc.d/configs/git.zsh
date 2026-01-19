#!/usr/bin/env zsh

# Load git lib (provides git_current_branch, git_main_branch functions)
zinit snippet OMZL::git.zsh

# Load git plugin immediately (provides aliases)
zinit ice lucid atload'unalias gf gfa gpsup gswm 2>/dev/null'
zinit snippet OMZP::git

zinit ice wait'0c' lucid
zinit snippet OMZP::git-extras

export GIT_COMPLETION_CHECKOUT_NO_GUESS=1 # only autocomplete with local branches

if [[ -n ${HOMEBREW_PREFIX} ]]; then
  PATH="${PATH}:${HOMEBREW_PREFIX}/opt/git/share/git-core/contrib/git-jump"
  export PATH
fi
