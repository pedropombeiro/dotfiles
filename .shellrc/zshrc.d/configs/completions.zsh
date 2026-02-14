#!/usr/bin/env zsh

_generate_completion() {
  local name=$1
  local cmd=$2
  local target=~/.config/zsh/site-functions/_${name}

  if [[ ! -f $target ]]; then
    eval "$cmd" >"$target"
    rm -f ~/.zcompdump* >/dev/null 2>&1
  fi
}

_generate_completion opencode 'opencode completion'

unfunction _generate_completion
