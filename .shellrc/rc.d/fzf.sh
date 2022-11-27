#!/usr/bin/env bash

## FZF_DEFAULT_COLOR defined in ~/.shellrc/rc.d/_theme.sh
export FZF_DEFAULT_OPTS="--height 40% --inline-info --border --ansi --bind ctrl-_:toggle-preview ${FZF_DEFAULT_COLOR} --preview 'bat --color=always --style=header,grid --line-range :300 {}'"

export FZF_DEFAULT_COMMAND='fd --type file --color=always --hidden --exclude .git --exclude=~/go/pkg'
if [[ "$(uname -s)" = "Darwin" ]]; then
  FZF_DEFAULT_COMMAND="${FZF_DEFAULT_COMMAND} --exclude=~/Library/Caches"
fi
