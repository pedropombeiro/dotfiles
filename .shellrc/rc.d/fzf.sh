#!/usr/bin/env bash

export FZF_DEFAULT_COMMAND='fd --type file --color=always --hidden --exclude .git --exclude=~/go/pkg'
export FZF_DEFAULT_OPTS='--ansi --height 40% --inline-info --border'

if [[ "$(uname -s)" = "Darwin" ]]; then
  FZF_DEFAULT_COMMAND="${FZF_DEFAULT_COMMAND} --exclude=~/Library/Caches"
fi

function j() {
    if [[ "$#" -ne 0 ]]; then
        cd "$(autojump $@)"
        return
    fi
    cd "$(autojump -s | sort -k1gr | awk '$1 ~ /[0-9]:/ && $2 ~ /^\// { for (i=2; i<=NF; i++) { print $(i) } }' |  fzf --height 40% --reverse --inline-info)" || exit
}
