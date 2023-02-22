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
      zcompile ${1}
    fi
  }

  setopt EXTENDED_GLOB

  # zcompile the completion cache; siginificant speedup.
  zcompare ${ZDOTDIR:-${HOME}}/.zcompdump
  zcompare ${HOME}/.zshrc
  zcompare ${HOME}/.zshrc.shared

  # zcompile all .zsh files in the theme
  for file in ${HOME}/.oh-my-zsh/custom/themes/powerlevel10k/**/*.zsh; do
    zcompare ${file}
  done

  for file in ${HOME}/.oh-my-zsh/lib/*.zsh; do
    zcompare ${file}
  done

  for file in ${HOME}/.oh-my-zsh/custom/plugins/*/*.zsh; do
    zcompare ${file}
  done

  for file in ${HOME}/.oh-my-zsh/plugins/{common-aliases,git,git-extras,history-substring-search}/*.zsh; do
    zcompare ${file}
  done

) &!

# Load all files from .shellrc/login.d directory
if [ -d "${HOME}/.shellrc/login.d" ]; then
  for file in ${HOME}/.shellrc/login.d/*.sh; do
    source $file
  done
fi
