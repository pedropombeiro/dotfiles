#!/usr/bin/env zsh

# Entware's global zprofile sets TERM=xterm, so ~/.zprofile restores this value.
typeset -g _zsh_inherited_term="$TERM"

[[ -r $HOME/.shellrc/rc.d/_xdg.sh ]] && source "$HOME/.shellrc/rc.d/_xdg.sh"
export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"
typeset -U path
