#!/usr/bin/env zsh

HISTFILE="${HISTFILE:-$HOME/.zsh_history}"
HISTSIZE=50000
SAVEHIST=10000
# Keep native history exclusions aligned with Atuin's explicit history_filter.
# The hook rejects persistence and removes the entry after the next command.
_shell_history_filter() {
  emulate -L zsh
  [[ $1 == ' '* || $1 == *op://* || $1 == *'/1PE'* ]] && return 1
  [[ $1 == export\ *TOKEN* || $1 == export\ *SECRET* || $1 == export\ *PASSWORD* ]] && return 1
  return 0
}
autoload -Uz add-zsh-hook
add-zsh-hook zshaddhistory _shell_history_filter
HISTORY_IGNORE='(*op://*|*/1PE*|export *TOKEN*|export *SECRET*|export *PASSWORD*)'

setopt EXTENDED_HISTORY       # Record timestamp of command in HISTFILE
setopt HIST_EXPIRE_DUPS_FIRST # Delete duplicates first when HISTFILE size exceeds HISTSIZE
setopt HIST_IGNORE_DUPS       # Ignore duplicated commands history list
setopt HIST_IGNORE_SPACE      # Ignore commands that start with space
setopt HIST_FIND_NO_DUPS      # Do not display a line previously found
setopt HIST_VERIFY            # Show command with history expansion to user before running it
unsetopt INC_APPEND_HISTORY   # SHARE_HISTORY already appends and imports history
setopt SHARE_HISTORY          # Share command history data
