#!/usr/bin/env bash

# ~/.zshenv sets this for zsh. Bash needs it too: some tools, such as
# pg_format, only check ~/.config when XDG_CONFIG_HOME is set explicitly.
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
