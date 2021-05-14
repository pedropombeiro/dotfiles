#!/usr/bin/env zsh

if command -v lab >/dev/null; then
  export FPATH="${HOME}/.shellrc/zshrc.d/configs/gitlab:${FPATH}"
fi
