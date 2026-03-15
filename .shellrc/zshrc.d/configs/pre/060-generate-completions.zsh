#!/usr/bin/env zsh

_generate_completion() {
  local name=$1
  local cmd=$2
  local target=~/.config/zsh/site-functions/_${name}

  # -s = exists and non-empty; regenerate if missing or empty (e.g. failed previous run)
  if [[ ! -s $target ]] && (( $+commands[$name] )); then
    eval "$cmd" >"$target" 2>/dev/null
    if [[ ! -s $target ]]; then
      rm -f "$target"
      return
    fi
    rm -f ~/.zcompdump*(N) 2>/dev/null
  fi
}

if (( $+commands[mise] )); then
  mise_bin=$commands[mise]
  mise_completion=~/.config/zsh/site-functions/_mise
  if [[ ! -f $mise_completion || $mise_completion -ot $mise_bin ]]; then
    mise complete -s zsh >$mise_completion
    rm -f ~/.zcompdump*(N) 2>/dev/null
  fi
fi

if (( $+commands[gh] )); then
  gh_bin=$commands[gh]
  gh_completion=~/.config/zsh/site-functions/_gh
  if [[ ! -f $gh_completion || $gh_completion -ot $gh_bin ]]; then
    gh completion -s zsh >$gh_completion
    rm -f ~/.zcompdump*(N) 2>/dev/null
  fi
fi

_generate_completion atuin 'atuin gen-completions --shell zsh'
_generate_completion opencode 'opencode completion'
_generate_completion sesh 'sesh completion zsh'
_generate_completion op 'op completion zsh'

unfunction _generate_completion
