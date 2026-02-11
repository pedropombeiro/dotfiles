#!/usr/bin/env zsh

# Load common-aliases via zinit with turbo mode
# Re-source custom aliases after plugin loads to override plugin defaults (e.g., `la`)
zinit ice wait'0b' lucid atload'unalias t 2>/dev/null; source ~/.shellrc/rc.d/aliases.sh'
zinit snippet OMZP::common-aliases
