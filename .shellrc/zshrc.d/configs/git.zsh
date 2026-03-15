#!/usr/bin/env zsh

# Load git lib + plugin via turbo (provides git_current_branch, aliases, etc.)
# Unalias OMZ git shortcuts that are replaced by custom functions in zshrc.d/functions/
zinit wait'0' lucid for \
  OMZL::git.zsh \
  atload'unalias gf gfa gp gpsup gswm 2>/dev/null' OMZP::git

zinit ice wait'0c' lucid
zinit snippet OMZP::git-extras

export GIT_COMPLETION_CHECKOUT_NO_GUESS=1 # only autocomplete with local branches

if [[ -n ${HOMEBREW_PREFIX} ]]; then
  # Add git-jump (contrib script for jumping to diff/grep/merge-conflict locations in $EDITOR)
  PATH="${PATH}:${HOMEBREW_PREFIX}/opt/git/share/git-core/contrib/git-jump"
  export PATH
fi
