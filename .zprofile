#!/usr/bin/env zsh

# Restore the TERM captured in ~/.zshenv after the global zprofile overwrites it.
[[ -n "${_zsh_inherited_term:-}" ]] && export TERM="$_zsh_inherited_term"
unset _zsh_inherited_term

# Added by Kiri: its docker and kiri commands (kiri setup --uninstall removes this)
case ":$PATH:" in *":$HOME/.kiri/bin:"*) ;; *) export PATH="$PATH:$HOME/.kiri/bin" ;; esac
