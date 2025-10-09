#!/usr/bin/env zsh

HISTSIZE=50000
SAVEHIST=4000
HISTORY_IGNORE='(\/1PE)'

setopt INC_APPEND_HISTORY # Write to the history file immediately, not when the shell exits.
setopt SHARE_HISTORY      # Share history between all sessions.
setopt HIST_IGNORE_DUPS   # Don't record an entry that was just recorded again.
setopt HIST_FIND_NO_DUPS  # Do not display a line previously found.
setopt sharehistory
setopt extendedhistory
setopt histignorespace
