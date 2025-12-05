#!/usr/bin/env bash
# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
alias ohmyzsh="\$EDITOR ~/.oh-my-zsh"
# shellcheck disable=SC2142  # This pattern works in bash/zsh
alias mkcd='mkcd_impl() { mkdir -p "$1" && cd "$1" || return; }; mkcd_impl'
alias myip="curl http://ipecho.net/plain; echo"
alias vimdiff="vim -d"

# Include custom aliases
if [[ -f ~/.aliases.local ]]; then
  # shellcheck source=/dev/null
  source ~/.aliases.local
fi
