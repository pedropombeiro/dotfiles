#!/usr/bin/env zsh

if command -v lab >/dev/null; then
  export FPATH=".shellrc/zshrc.d/configs/gitlab:${FPATH}"
fi
