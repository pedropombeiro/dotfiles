#!/usr/bin/env zsh

# Set TERM only if not already set by terminal emulator or tmux
if [[ -z "$TERM" || "$TERM" == "dumb" ]]; then
  export TERM="xterm-256color"
fi

# Make Ctrl-W stop at path separators, dashes, etc. (but not underscores)
WORDCHARS='_'

# Directory navigation (setopts here for immediate availability; aliases loaded via OMZL::directories in common-aliases.zsh)
setopt AUTO_CD           # If command is a directory path, cd into it
setopt AUTO_PUSHD        # Make cd push the old directory onto the stack
setopt PUSHD_IGNORE_DUPS # Don't push multiple copies of the same directory
setopt PUSHDMINUS        # Swap meaning of + and - for pushd

# Say how long a command took, if it took more than 10 seconds
REPORTTIME=10

# Display red dots whilst waiting for completion
COMPLETION_WAITING_DOTS="true"

# Don't mark untracked files under VCS as dirty (faster for large repos)
DISABLE_UNTRACKED_FILES_DIRTY="true"

# History timestamp format
HIST_STAMPS="yyyy-mm-dd"

# zsh-autosuggestions config
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
