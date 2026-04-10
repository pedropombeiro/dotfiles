#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Paste formatted SQL in codefence
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🤖
# @raycast.packageName com.pedropombeiro.pastesql

# Documentation:
# @raycast.description Paste formatted SQL
# @raycast.author Pedro Pombeiro
# @raycast.authorURL https://pedropombeiro.com

original=$(pbpaste)

echo "$original" | \
  sed 's/\\"/"/g' | \
  /opt/homebrew/bin/pg_format --nocomment - | \
  xargs -0 printf "\`\`\`sql\n%s\`\`\`" | \
  pbcopy

osascript -e 'tell application "System Events" to keystroke "v" using command down'
sleep 0.5
echo "$original" | pbcopy

