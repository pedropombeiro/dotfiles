#!/usr/bin/env zsh

export CONFIG_HOME=/share/Container

# Choose the startup directory before 110-mise.zsh resolves its environment.
# SHLVL=1: initial shell, before the deferred tmux plugin starts tmux.
# Nested tmux shells starting in HOME also need the Compose repo so OSC 7
# reports the correct pane path. Preserve inherited directories in other panes.
if [[ ${SHLVL} -le 1 || (-n "$TMUX" && "$PWD" == "$HOME") ]]; then
  cd "${CONFIG_HOME}"
fi
