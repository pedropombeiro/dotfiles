#!/usr/bin/env zsh

if [[ -z $HOMEBREW_PREFIX ]]; then
  if command -v brew > /dev/null; then
    HOMEBREW_PREFIX="$(brew --prefix 2>/dev/null)"
  elif [[ -x /opt/homebrew/bin/brew ]]; then
    # Apple Silicon uses a different prefix
    HOMEBREW_PREFIX="$(/opt/homebrew/bin/brew --prefix 2>/dev/null)"
  fi
  [[ -n $HOMEBREW_PREFIX ]] && export HOMEBREW_PREFIX
fi
