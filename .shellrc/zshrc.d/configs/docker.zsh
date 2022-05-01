#!/usr/bin/env zsh

if [[ -d ${HOME}/.rd/bin ]]; then
  # Add Rancher Desktop path to environment
  PATH="${HOME}/.rd/bin:$PATH"
  export PATH
fi

if command -v docker > /dev/null; then
  plugins+=(docker docker-compose)
elif command -v docker-machine > /dev/null; then
  plugins+=(docker docker-compose)
fi
