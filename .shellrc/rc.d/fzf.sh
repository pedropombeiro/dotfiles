#!/usr/bin/env bash

# Gruvbox theme
export FZF_DEFAULT_OPTS='--color=bg+:#3c3836,bg:#32302f,spinner:#fb4934,hl:#928374,fg:#ebdbb2,header:#928374,info:#8ec07c,pointer:#fb4934,marker:#fb4934,fg+:#ebdbb2,prompt:#fb4934,hl+:#fb4934'
export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS} --height 40% --inline-info --border"

export FZF_DEFAULT_COMMAND='fd --type file --color=always --hidden --exclude .git --exclude=~/go/pkg'
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
