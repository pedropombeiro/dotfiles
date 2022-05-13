#!/usr/bin/env zsh

if [[ -d ${HOME}/.rd/bin ]]; then
  # Add Rancher Desktop path to environment
  PATH="${HOME}/.rd/bin:$PATH"
  export PATH
fi

plugins+=(docker docker-compose)
