#!/usr/bin/env bash
# Set personal aliases, overriding those provided by plugins.
# For a full list of active aliases, run `alias`.
#
# Example aliases
alias zinit-home="\$EDITOR \${XDG_DATA_HOME:-\$HOME/.local/share}/zinit"
# shellcheck disable=SC2142  # This pattern works in bash/zsh
alias mkcd='mkcd_impl() { mkdir -p "$1" && cd "$1" || return; }; mkcd_impl'
alias myip="curl http://ipecho.net/plain; echo"
alias vimdiff="vim -d"

# Include custom aliases
if [[ -f ~/.aliases.local ]]; then
  # shellcheck source=/dev/null
  source ~/.aliases.local
fi
