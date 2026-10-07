#!/usr/bin/env bash

# XDG base directories. ~/.zshenv sources this file so non-interactive zsh,
# such as agent shells, also gets them. Bash loads it with the other rc.d
# files. mise reads its own config from XDG_CONFIG_HOME, so this can't move to
# mise's [env]. Put other tool overrides in ~/.config/mise/conf.d/global.toml.

# Some tools, such as pg_format, only check ~/.config when this is set.
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
