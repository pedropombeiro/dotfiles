#!/usr/bin/env bash

export HIGHLIGHT_TABWIDTH=2
# highlight only searches ~/.highlight/ by default, not XDG directories.
# The trailing slash is required: highlight appends "themes/" without one.
export HIGHLIGHT_DATADIR="${XDG_CONFIG_HOME:-$HOME/.config}/highlight/"
