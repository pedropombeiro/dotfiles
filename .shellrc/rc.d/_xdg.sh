#!/usr/bin/env bash

# XDG base directories and the tool overrides that keep files out of $HOME.
# ~/.zshenv sources this file so non-interactive zsh, such as agent shells,
# also gets these variables. Bash loads it with the other rc.d files.

# Some tools, such as pg_format, only check ~/.config when this is set.
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

# Default: ~/.npm
export npm_config_cache="${XDG_CACHE_HOME:-$HOME/.cache}/npm"
# Default: ~/.bundle/cache
export BUNDLE_USER_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/bundler"
