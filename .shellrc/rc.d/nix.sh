#!/usr/bin/env bash

if [ -e "${HOME}"/.nix-profile/etc/profile.d/nix.sh ]; then
  [[ "${OSTYPE}" == "darwin"* ]] && export NIX_IGNORE_SYMLINK_STORE=1
  # shellcheck source=/dev/null
  . "$HOME"/.nix-profile/etc/profile.d/nix.sh
fi
