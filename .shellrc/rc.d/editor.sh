#!/usr/bin/env bash

# Preferred editor for local and remote sessions
if [[ -n "${SSH_CONNECTION}" ]]; then
  export EDITOR='nvim'
else
  export EDITOR='nvim'
fi

export VISUAL=${EDITOR}
export REACT_EDITOR=code
