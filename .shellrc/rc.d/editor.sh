#!/usr/bin/env bash

# Preferred editor for local and remote sessions.
# Inside a neovim terminal, use nvr (neovim-remote) to open files in a split of
# the parent instance instead of nesting. --remote-wait blocks until the buffer
# is closed, and bufhidden=wipe auto-deletes it so :q returns control to the shell.
if [[ -n "$NVIM_LISTEN_ADDRESS" ]]; then
  export EDITOR="nvr -cc split --remote-wait +'set bufhidden=wipe'"
else
  export EDITOR="nvim"
fi

export VISUAL=${EDITOR}

if [[ -n "$NVIM_LISTEN_ADDRESS" ]]; then
  alias nvim=nvr -cc split --remote-wait +'set bufhidden=wipe'
fi
