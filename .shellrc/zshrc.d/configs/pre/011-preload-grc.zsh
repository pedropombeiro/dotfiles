#!/usr/bin/env zsh

# Powerlevel10k Instant Prompt prevents grc.zsh from having a working tty,
# so we need to make sure we source grc before kicking off Instant Prompt
# (012-enable-instant-prompt.zsh). Requires HOMEBREW_PREFIX from 010-brew.sh.
if [[ -s "${HOMEBREW_PREFIX}/etc/grc.zsh" ]]; then
  source "${HOMEBREW_PREFIX}/etc/grc.zsh"
elif [[ -s /etc/grc.zsh ]]; then
  source /etc/grc.zsh
fi

# grc wraps `make` as a shell function that mangles env/stdin when used as a
# script runner (e.g. yadm bootstrap calling update.zsh via make). Remove it.
unset -f make 2>/dev/null
