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

typeset -g POWERLEVEL9K_MODE='awesome-fontconfig'

typeset -g POWERLEVEL9K_DIR_HOME_FOREGROUND='gray93'
typeset -g POWERLEVEL9K_DIR_HOME_SUBFOLDER_FOREGROUND='white'
typeset -g POWERLEVEL9K_DIR_DEFAULT_FOREGROUND='gray89'
typeset -g POWERLEVEL9K_USER_ICON="\uF415" # 
typeset -g POWERLEVEL9K_ROOT_ICON='#'
typeset -g POWERLEVEL9K_SUDO_ICON=$'\uF09C' # 
typeset -g POWERLEVEL9K_DIR_NOT_WRITABLE_VISUAL_IDENTIFIER_COLOR=red
typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(user dir dir_writable newline vcs)
typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
  status
  vpn_ip
  yazi
  direnv    # direnv status (https://direnv.net/)
  background_jobs
  history
  ram
  time
)
typeset -g POWERLEVEL9K_PROMPT_ON_NEWLINE=false

# Prevent gitstatusd from scanning dirty files in repositories with >20K files
typeset -g POWERLEVEL9K_VCS_MAX_INDEX_SIZE_DIRTY=20000

# Increase timeout to prevent the branch indicator from disappearing
typeset -g POWERLEVEL9K_VCS_MAX_SYNC_LATENCY_SECONDS=1.0

# Hot reload allows you to change POWERLEVEL9K options
# after Powerlevel10k has been initialized. For example,
# you can type POWERLEVEL9K_FOREGROUND=red and see your
# prompt turn red. Hot reload can slow down prompt by
# 1-2 milliseconds, so it's better to keep it turned off
# unless you really need it.
typeset -g POWERLEVEL9K_DISABLE_HOT_RELOAD=true
