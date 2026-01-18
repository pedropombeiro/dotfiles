#!/usr/bin/env zsh

# Remove problematic aliases
unalias duf 2>/dev/null
unalias t 2>/dev/null # Allow ~/.shellrc/zshrc.d/functions/t to override the t alias

unalias gf 2>/dev/null # Overriden as a more specialized function
unalias gfa 2>/dev/null # Overriden as a more specialized function
