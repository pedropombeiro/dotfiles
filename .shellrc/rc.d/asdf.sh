#!/usr/bin/env bash

if command -v brew >/dev/null; then
  if brew --prefix asdf >/dev/null; then
    . $(brew --prefix asdf)/asdf.sh
  fi
fi
