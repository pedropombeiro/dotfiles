#!/usr/bin/env bash

# Preferred editor for local and remote sessions
if [ -n "$NVIM_LISTEN_ADDRESS" ]; then
  export EDITOR="nvr -cc split --remote-wait +'set bufhidden=wipe'"
else
  export EDITOR="nvim"
fi

export VISUAL=${EDITOR}

if [ -n "$NVIM_LISTEN_ADDRESS" ]; then
  alias nvim=nvr -cc split --remote-wait +'set bufhidden=wipe'
fi
