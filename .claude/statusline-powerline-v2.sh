#!/usr/bin/env bash

# Claude Code Status Line - Powerline/Powerlevel10k style with Gruvbox-dark colors
# Shows: current directory, git branch, combined model/context with colored segments

input=$(cat)

# Extract values from JSON input
current_dir=$(echo "$input" | jq -r '.workspace.current_dir')
model_name=$(echo "$input" | jq -r '.model.display_name')
context_window=$(echo "$input" | jq -r '.context_window')

dir_name="$current_dir"

# Replace home directory with ~
if [[ "$dir_name" == "$HOME" ]]; then
  dir_name="~"
elif [[ "$dir_name" == "$HOME"/* ]]; then
  dir_name="~${dir_name#"$HOME"}"
fi

# Get git branch (skip optional locks for performance)
git_branch=""
if git -C "$current_dir" rev-parse --git-dir >/dev/null 2>&1; then
  git_branch=$(git -C "$current_dir" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || \
    git -C "$current_dir" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
fi

# Calculate context usage percentage
usage=$(echo "$context_window" | jq '.current_usage')
context_pct=""
if [ "$usage" != "null" ]; then
  current=$(echo "$usage" | jq '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
  size=$(echo "$context_window" | jq '.context_window_size')
  if [ "$current" != "null" ] && [ "$size" != "null" ] && [ "$size" -gt 0 ]; then
    pct=$((current * 100 / size))
    context_pct="${pct}%"
  fi
fi

# Gruvbox-dark subtle color codes (matching lualine aesthetic)
# Using muted background shades for a professional, cohesive look
DIR_BG="241"     # Gruvbox bg3 (#665c54) - Lighter dark gray
DIR_FG="223"     # Gruvbox fg1 (#ebdbb2) - Light beige
GIT_BG="239"     # Gruvbox bg2 (#504945) - Medium dark gray
GIT_FG="223"     # Gruvbox fg1 (#ebdbb2) - Light beige
MODEL_BG="237"   # Gruvbox bg1 (#3c3836) - Subtle dark gray (darkest)
MODEL_FG="223"   # Gruvbox fg1 (#ebdbb2) - Light beige
SEP="" # Powerline separator (U+E0B0)

# Directory segment
printf "\033[48;5;%sm\033[38;5;%sm  %s " "$DIR_BG" "$DIR_FG" "$dir_name"

# Git branch segment (if in git repo)
if [ -n "$git_branch" ]; then
  printf "\033[38;5;%sm\033[48;5;%sm%s" "$DIR_BG" "$GIT_BG" "$SEP"
  printf "\033[38;5;%sm  %s " "$GIT_FG" "$git_branch"
  LAST_BG="$GIT_BG"
else
  LAST_BG="$DIR_BG"
fi

# Combined model/context segment
if [ -n "$model_name" ] && [ "$model_name" != "null" ]; then
  printf "\033[38;5;%sm\033[48;5;%sm%s" "$LAST_BG" "$MODEL_BG" "$SEP"
  printf "\033[38;5;%sm  %s" "$MODEL_FG" "$model_name"
  if [ -n "$context_pct" ]; then
    printf " %s  %s " "" "$context_pct"
  else
    printf " "
  fi
  LAST_BG="$MODEL_BG"
elif [ -n "$context_pct" ]; then
  printf "\033[38;5;%sm\033[48;5;%sm%s" "$LAST_BG" "$MODEL_BG" "$SEP"
  printf "\033[38;5;%sm  %s " "$MODEL_FG" "$context_pct"
  LAST_BG="$MODEL_BG"
fi

# Final separator to close the bar
printf "\033[0m\033[38;5;%sm%s\033[0m" "$LAST_BG" "$SEP"
