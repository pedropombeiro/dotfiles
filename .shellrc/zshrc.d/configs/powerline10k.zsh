#!/usr/bin/env zsh

# Set name of the theme to load --- if set to "random", it will load a random theme each time oh-my-zsh is loaded, in which
# case, to know which specific one was loaded, run: echo $RANDOM_THEME See
# https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
#ZSH_THEME="robbyrussell"
#ZSH_THEME="agnoster"
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in ~/.oh-my-zsh/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

typeset -g POWERLEVEL9K_DIR_HOME_FOREGROUND='gray93'
typeset -g POWERLEVEL9K_DIR_HOME_SUBFOLDER_FOREGROUND='white'
typeset -g POWERLEVEL9K_DIR_DEFAULT_FOREGROUND='gray89'
typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(user dir newline vcs)
typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
  status
  root_indicator
  direnv                  # direnv status (https://direnv.net/)
  ranger                  # ranger shell (https://github.com/ranger/ranger)
  vim_shell               # vim shell indicator (:sh)
  nix_shell               # nix shell (https://nixos.org/nixos/nix-pills/developing-with-nix-shell.html)
  background_jobs
  history
  ram
  time
)
typeset -g POWERLEVEL9K_PROMPT_ON_NEWLINE=false

# Hot reload allows you to change POWERLEVEL9K options
# after Powerlevel10k has been initialized. For example,
# you can type POWERLEVEL9K_FOREGROUND=red and see your
# prompt turn red. Hot reload can slow down prompt by
# 1-2 milliseconds, so it's better to keep it turned off
# unless you really need it.
typeset -g POWERLEVEL9K_DISABLE_HOT_RELOAD=true

