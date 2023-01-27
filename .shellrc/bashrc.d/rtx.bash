#!/usr/bin/env bash

if [ -x "${HOME}/.local/share/rtx/bin/rtx" ]; then
  eval "$("${HOME}/.local/share/rtx/bin/rtx" activate bash)"
elif command -v ftx >/dev/null; then
  eval "$(rtx activate bash)"
fi
