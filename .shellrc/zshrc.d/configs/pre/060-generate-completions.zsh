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

if command -v mise &>/dev/null; then
  mise_bin=$(command -v mise)
  mise_completion=~/.config/zsh/site-functions/_mise
  if [[ ! -f $mise_completion || $mise_completion -ot $mise_bin ]]; then
    mise complete -s zsh >$mise_completion
    rm -f ~/.zcompdump* >/dev/null 2>&1
  fi
fi

if command -v gh &>/dev/null; then
  gh_bin=$(command -v gh)
  gh_completion=~/.config/zsh/site-functions/_gh
  if [[ ! -f $gh_completion || $gh_completion -ot $gh_bin ]]; then
    gh completion -s zsh >$gh_completion
    rm -f ~/.zcompdump* >/dev/null 2>&1
  fi
fi

_generate_completion atuin 'atuin gen-completions --shell zsh'
_generate_completion opencode 'opencode completion'
_generate_completion sesh 'sesh completion zsh'
_generate_completion op 'op completion zsh'

unfunction _generate_completion
