#!/usr/bin/env bash

if [ -x "${HOME}/.local/share/mise/bin/mise" ]; then
  eval "$("${HOME}/.local/share/mise/bin/mise" activate bash)"
elif command -v ftx >/dev/null; then
  eval "$(mise activate bash)"
fi
