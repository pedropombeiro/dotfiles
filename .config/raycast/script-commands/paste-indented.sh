#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Paste indented
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🤖
# @raycast.packageName com.pedropombeiro.pasteindented

# Documentation:
# @raycast.description Indent clipboard contents by 4 spaces and paste
# @raycast.author Pedro Pombeiro
# @raycast.authorURL https://pedropombeiro.com

original=$(pbpaste)

sed 's/^/    /' <<< "$original" | pbcopy

osascript -e 'tell application "System Events" to keystroke "v" using command down'
sleep 0.5
echo "$original" | pbcopy
