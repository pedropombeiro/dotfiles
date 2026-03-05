#!/usr/bin/env bash
#
# Pre-commit hook: reject staged files that are yadm alt symlinks.
# Called by pre-commit with filenames as arguments.

alt_basenames=$(yadm ls-files | grep -E '##' | sed 's/##.*//' | sort -u)

if [[ -z "${alt_basenames}" ]]; then
  exit 0
fi

bad_files=()
for file in "$@"; do
  if echo "${alt_basenames}" | grep -qxF "${file}"; then
    bad_files+=("${file}")
  fi
done

if [[ ${#bad_files[@]} -gt 0 ]]; then
  echo "ERROR: The following staged files are yadm alt symlinks and must not be committed:"
  for f in "${bad_files[@]}"; do
    echo "  ${f}"
  done
  echo ""
  echo "Run 'yadm reset HEAD <file>' to unstage them."
  exit 1
fi
