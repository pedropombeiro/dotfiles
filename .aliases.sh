#!/usr/bin/env bash
# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
alias ohmyzsh="\$EDITOR ~/.oh-my-zsh"
alias mkcd='foo(){ mkdir -p "$1"; cd "$1" }; foo'
alias myip="curl http://ipecho.net/plain; echo"
alias vimdiff="vim -d"

# Include custom aliases
if [[ -f ~/.aliases.local ]]; then
  source ~/.aliases.local
fi
