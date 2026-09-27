#!/usr/bin/env zsh

# Name local initialization tasks in `zinit times` without cloning a no-op plugin.
_defer_shell_init() {
  zinit ice wait"$1" lucid nocd as"null" id-as"shell/$2" atload"$3"
  zinit light "$HOME/.shellrc/zshrc.d"
}
