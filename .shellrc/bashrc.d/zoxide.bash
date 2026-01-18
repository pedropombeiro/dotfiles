#!/usr/bin/env bash

# zoxide - fast directory jumping (replacement for autojump)
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init bash)"
  alias j='z'   # autojump compatibility
  alias ji='zi' # interactive mode
fi
