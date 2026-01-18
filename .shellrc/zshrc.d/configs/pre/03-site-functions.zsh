#!/usr/bin/env zsh

mkdir -p $HOME/.config/zsh/site-functions
fpath+=($HOME/.config/zsh/site-functions)

# Recreate any compdump older than a day (using zsh glob instead of slow find)
# (N) = nullglob, (.) = regular files, (md+1) = modified more than 1 day ago
rm -f $HOME/.zcompdump*(N.md+1) 2>/dev/null
