#!/usr/bin/env bash

# Preferred editor for local and remote sessions
if [[ -n "${SSH_CONNECTION}" ]]; then
  export EDITOR='nano'
else
  export EDITOR='nano'
fi

export VISUAL=${EDITOR}
export REACT_EDITOR=code