# Set name of the theme to load --- if set to "random", it will load a random theme each time oh-my-zsh is loaded, in which
# case, to know which specific one was loaded, run: echo $RANDOM_THEME See
# https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
#ZSH_THEME="robbyrussell"
#ZSH_THEME="agnoster"
export TERM="xterm-256color"
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in ~/.oh-my-zsh/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

POWERLEVEL9K_DIR_HOME_FOREGROUND='gray93'
POWERLEVEL9K_DIR_HOME_SUBFOLDER_FOREGROUND='white'
POWERLEVEL9K_DIR_DEFAULT_FOREGROUND='gray89'
POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(user dir newline vcs)
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status root_indicator background_jobs history ram time)
POWERLEVEL9K_PROMPT_ON_NEWLINE=false
