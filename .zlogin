#!/usr/bin/env zsh

# .zlogin

#
# startup file read in interactive login shells
#
# The following code helps us by optimizing the existing framework.
# This includes zcompile, zcompdump, etc.
#

(
  # Function to determine the need of a zcompile. If the .zwc file
  # does not exist, or the base file is newer, we need to compile.
  # These jobs are asynchronous, and will not impact the interactive shell
  function zcompare() {
    if [[ -s ${1} && ( ! -s ${1}.zwc || ${1} -nt ${1}.zwc) ]]; then
      zcompile -R -- "${1}.zwc" "$1"
    fi
  }

  setopt EXTENDED_GLOB

  # zcompile the completion cache; significant speedup.
  zcompare ${ZDOTDIR:-${HOME}}/.zcompdump
  zcompare ${HOME}/.zshrc
  zcompare ${HOME}/.zshrc.shared

  # Note: zinit handles its own zcompile during updates

) &!

# Load all files from .shellrc/login.d directory
if [ -d "${HOME}/.shellrc/login.d" ]; then
  for file in ${HOME}/.shellrc/login.d/*.sh; do
    source $file
  done
fi
