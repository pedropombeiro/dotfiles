#!/usr/bin/env zsh

if [[ -f "${HOMEBREW_PREFIX}/opt/asdf/libexec/asdf.sh" ]]; then
  source "${HOMEBREW_PREFIX}/opt/asdf/libexec/asdf.sh"
else
  if ! type asdf >/dev/null; then
    plugins+=(asdf)
  fi
fi
