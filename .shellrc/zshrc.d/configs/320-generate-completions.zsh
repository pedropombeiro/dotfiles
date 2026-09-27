#!/usr/bin/env zsh

_generate_completion() {
  local name=$1
  local cmd=$2
  local target=~/.config/zsh/site-functions/_${name}
  local refresh=${3:-missing}
  local tmp="${target}.tmp.$$"

  (( $+commands[$name] )) || return

  # -s = exists and non-empty; regenerate if missing or empty (e.g. failed previous run)
  if [[ ! -s $target || ($refresh == binary && $target -ot $commands[$name]) ]]; then
    # Preserve the last good completion if generation fails or a shell is interrupted.
    if eval "$cmd" >"$tmp" 2>/dev/null && [[ -s $tmp ]]; then
      mv -f -- "$tmp" "$target"
    else
      rm -f -- "$tmp"
    fi
  fi
}

_generate_completion mise 'mise complete -s zsh' binary
_generate_completion gh 'gh completion -s zsh' binary
_generate_completion atuin 'atuin gen-completions --shell zsh'
_generate_completion opencode 'opencode --completions zsh'
_generate_completion sesh 'sesh completion zsh'
_generate_completion op 'op completion zsh'

unfunction _generate_completion
