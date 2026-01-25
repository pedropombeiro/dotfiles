#!/usr/bin/env zsh

# Powerlevel10k Instant Prompt prevents grc.zsh from having a working tty,
# so we need to make sure we source grc before kicking off Instant Prompt.
if [[ -s "${HOMEBREW_PREFIX}/etc/grc.zsh" ]]; then
  source "${HOMEBREW_PREFIX}/etc/grc.zsh"
elif [[ -s /etc/grc.zsh ]]; then
  source /etc/grc.zsh
fi

# Unset make, as the grc implementation gets confused when invoking the yadm update.sh script through it
unset -f make 2>/dev/null
