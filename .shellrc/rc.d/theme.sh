#!/usr/bin/env sh

# List themes supported by highlight, used by Ranger (http://www.andre-simon.de/doku/highlight/en/theme-samples.php):
#   highlight --list-scripts themes
# List themes supported by bat (also used by delta):
#   bat --list-themes
# Themes supported by vim:
#   https://github.com/themercorp/themer.lua#-supported-colorschemes
# Themes supported by xh: auto, solarized, monokai, fruity

#export BAT_THEME='Monokai Extended Origin' # ~/.config/bat/config
#export HIGHLIGHT_STYLE=base16/monokai
#export NVIM_THEME=monokai # ~/.config/nvim/lua/config/themer.lua
#export XH_STYLE=monokai # ~/.shellrc/rc.d/aliases.sh

export BAT_THEME=gruvbox-dark # ~/.config/bat/config (also picked up by delta)
export HIGHLIGHT_STYLE=gruvbox-dark-medium
export NVIM_THEME=gruvbox # ~/.config/nvim/lua/config/themer.lua
export XH_STYLE=monokai # ~/.shellrc/rc.d/aliases.sh

# - tmux requires installing a plugin to implement a theme, see ~/.shellrc/zshrc.d/configs/tmux-common.conf
# - delta reads its theme from .config/dotfiles/git/gitconfig (delta.syntax-theme) which does not support environment variables
