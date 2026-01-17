#!/usr/bin/env zsh

export TERM="xterm-256color"

# Say how long a command took, if it took more than 10 seconds
REPORTTIME=10

# Display red dots whilst waiting for completion
COMPLETION_WAITING_DOTS="true"

# Don't mark untracked files under VCS as dirty (faster for large repos)
DISABLE_UNTRACKED_FILES_DIRTY="true"

# History timestamp format
HIST_STAMPS="yyyy-mm-dd"

if [[ -n $HOMEBREW_PREFIX ]]; then
  export MANPATH="${HOMEBREW_PREFIX}/man:$MANPATH"
fi

# zsh-autosuggestions config
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
