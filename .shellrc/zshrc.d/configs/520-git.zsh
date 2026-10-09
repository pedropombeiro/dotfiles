#!/usr/bin/env zsh

# Load git lib + plugin via turbo (provides git_current_branch, aliases, etc.)
# Unalias OMZ git shortcuts that are replaced by custom functions in zshrc.d/functions/
_defer_shell_init 0 git '
  zinit snippet OMZL::git.zsh
  zinit ice atload"unalias gf gfa gp gpf gpsup gswm 2>/dev/null"
  zinit snippet OMZP::git
'

zinit ice wait'0c' lucid
zinit snippet OMZP::git-extras

export GIT_COMPLETION_CHECKOUT_NO_GUESS=1 # only autocomplete with local branches

# Custom functions from zshrc.d/functions join fpath after compinit, so register them here
compdef _git gp=git-push
compdef _git_prune git_prune
compdef _precommand y
