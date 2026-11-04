#!/usr/bin/env zsh
#
# Pre-commit hook: reject staged files that are yadm alt symlinks.
# Called by pre-commit with filenames as arguments.

# Call git directly: yadm reruns `alt` after git commands, which deletes and
# recreates every alternate symlink and races with the other hooks.
local yadm_repo="${XDG_DATA_HOME:-$HOME/.local/share}/yadm/repo.git"

# Split into lines first: stripping `##…` from the joined output would remove
# everything after the first alternate.
# (f) splits on newlines, (M) keeps matching, (u) deduplicates
local -a tracked=( ${(f)"$(git --git-dir="$yadm_repo" --work-tree="$HOME" ls-files)"} )
local -a alt_basenames=( ${(u)${(M)tracked:#*\#\#*}%%\#\#*} )

if (( ${#alt_basenames} == 0 )); then
  exit 0
fi

local -a bad_files=()
for file in "$@"; do
  # (Ie) = exact match index in array; non-zero means found
  (( ${alt_basenames[(Ie)${file}]} )) && bad_files+=("${file}")
done

if (( ${#bad_files} > 0 )); then
  echo "ERROR: The following staged files are yadm alt symlinks and must not be committed:"
  for f in "${bad_files[@]}"; do
    echo "  ${f}"
  done
  echo ""
  echo "Run 'yadm reset HEAD <file>' to unstage them."
  exit 1
fi
