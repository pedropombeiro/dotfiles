#!/usr/bin/env bash

# Claude Code Status Line - Powerlevel10k inspired
# Shows: current directory, git branch, model name, context usage

input=$(cat)

# Extract values from JSON input
current_dir=$(echo "$input" | jq -r '.workspace.current_dir')
model_name=$(echo "$input" | jq -r '.model.display_name')
context_window=$(echo "$input" | jq -r '.context_window')

# Get directory name (like \W in PS1)
dir_name=$(basename "$current_dir")

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

# Build status line with segments (powerlevel10k style)
output=""

# Directory segment
output="${output}  ${dir_name}"

# Git branch segment (if in git repo)
if [ -n "$git_branch" ]; then
  output="${output}   ${git_branch}"
fi

# Model name segment (if available)
if [ -n "$model_name" ] && [ "$model_name" != "null" ]; then
  output="${output}  ${model_name}"
fi

# Context usage segment (if available)
if [ -n "$context_pct" ]; then
  output="${output} @ ${context_pct}"
fi

printf '%s' "$output"
