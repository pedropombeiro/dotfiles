#!/usr/bin/env zsh

# Add git-jump before mise captures the startup environment.
if [[ -n ${HOMEBREW_PREFIX} ]]; then
  path+=("${HOMEBREW_PREFIX}/opt/git/share/git-core/contrib/git-jump")
fi
