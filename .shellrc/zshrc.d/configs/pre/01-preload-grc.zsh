#!/usr/bin/env zsh

# Powerlevel10k Instant Prompt prevents grc.zsh from having a working tty,
# so we need to make sure we source grc before kicking off Instant Prompt.
source ~/.shellrc/zshrc.d/configs/grc.zsh
