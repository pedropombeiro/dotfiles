#!/usr/bin/env zsh

mkdir -p $HOME/.config/zsh/site-functions
fpath+=($HOME/.config/zsh/site-functions)

# make oh-my-zsh.sh recreate any compdump older than a day
find $HOME -maxdepth 1 -iname '.zcompdump*' -mtime 1 -delete
