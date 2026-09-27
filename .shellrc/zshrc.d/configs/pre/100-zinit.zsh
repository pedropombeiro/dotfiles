#!/usr/bin/env zsh

# Bootstrap zinit plugin manager
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

if [[ ! -d "$ZINIT_HOME" ]]; then
  print -P "%F{33}Installing zinit...%f"
  mkdir -p "${ZINIT_HOME:h}" # :h = head (dirname)
  git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

source "${ZINIT_HOME}/zinit.zsh"

# Initialize once, after all completion files and zinit's fpath entries exist.
# Mise's tool completions also need compdef, so activate mise after this file.
# Use -C only when the dump exists; 090-completion-cache.zsh removes stale dumps.
autoload -Uz compinit
if [[ -f $HOME/.zcompdump ]]; then
  compinit -C -u
else
  compinit -u
fi
