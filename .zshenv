#!/usr/bin/env zsh

[[ -r $HOME/.shellrc/rc.d/_xdg.sh ]] && source "$HOME/.shellrc/rc.d/_xdg.sh"
export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"
typeset -U path
