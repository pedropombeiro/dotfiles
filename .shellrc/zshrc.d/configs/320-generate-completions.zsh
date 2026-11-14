#!/usr/bin/env zsh

# Regenerate everything once after this file changes, such as a new transform.
_generate_completion_source=${(%):-%x}

_generate_completion() {
  local name=$1
  local cmd=$2
  local target=~/.config/zsh/site-functions/_${name}
  local refresh=${3:-missing}
  local tmp="${target}.tmp.$$"

  (( $+commands[$name] )) || return

  # -s = exists and non-empty; regenerate if missing or empty (e.g. failed previous run)
  if [[ ! -s $target || $target -ot $_generate_completion_source ||
        ($refresh == binary && $target -ot $commands[$name]) ]]; then
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
_generate_completion cheat 'cheat --completion zsh' binary
# Turn Carapace's snippet into an autoloaded `_carapace` function. Keep its
# command list as a comment instead of registering every command, so
# 595-carapace.zsh can use it only where no other completion exists. Drop the
# PATH entry for user spec binaries, which this setup doesn't use.
# Carapace filters values itself, case-insensitively like the first
# matcher-list entry, so skip the later matcher passes. Each pass would run
# Carapace again and repeat its message.
_generate_completion carapace '() {
  setopt localoptions pipefail
  print "#autoload" &&
    CARAPACE_ENV=0 carapace _carapace zsh |
    sed -e "/^export PATH=/d" -e "s/^compdef _carapace_completer /# carapace-commands: /" &&
    print -r -- "(( \${_matcher_num:-1} > 1 )) && return 1" &&
    print -r -- "CARAPACE_MATCH=1 _carapace_completer \"\$@\""
}' binary

unfunction _generate_completion
unset _generate_completion_source
