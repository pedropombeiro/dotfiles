#!/usr/bin/env zsh

HISTFILE="${HISTFILE:-$HOME/.zsh_history}"
HISTSIZE=50000
SAVEHIST=10000
HISTORY_IGNORE='(\/1PE)'

setopt EXTENDED_HISTORY       # Record timestamp of command in HISTFILE
setopt HIST_EXPIRE_DUPS_FIRST # Delete duplicates first when HISTFILE size exceeds HISTSIZE
setopt HIST_IGNORE_DUPS       # Ignore duplicated commands history list
setopt HIST_IGNORE_SPACE      # Ignore commands that start with space
setopt HIST_FIND_NO_DUPS      # Do not display a line previously found
setopt HIST_VERIFY            # Show command with history expansion to user before running it
setopt INC_APPEND_HISTORY     # Write to the history file immediately, not when the shell exits
setopt SHARE_HISTORY          # Share command history data
