#!/usr/bin/env sh
# Read-only validator for YADM patches (used before Plannotator review).
# Rejects option flags and multiple arguments so it can never apply a patch.

set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: check-yadm-patch.sh <patch-file>" >&2
  exit 2
fi

patch_file="$1"
case "$patch_file" in
"" | -*)
  echo "error: patch path must be a single file path, not an option: $patch_file" >&2
  exit 2
  ;;
esac

if [ ! -f "$patch_file" ]; then
  echo "error: patch file not found: $patch_file" >&2
  exit 2
fi

patch_dir=$(cd "$(dirname "$patch_file")" && pwd -P)
abs_patch_file="$patch_dir/$(basename "$patch_file")"

yadm_repo="${XDG_DATA_HOME:-$HOME/.local/share}/yadm/repo.git"
if [ ! -d "$yadm_repo" ]; then
  echo "error: yadm repository not found at $yadm_repo" >&2
  exit 2
fi

cd "$HOME"
git --git-dir="$yadm_repo" --work-tree="$HOME" apply --check -- "$abs_patch_file"
git --git-dir="$yadm_repo" --work-tree="$HOME" apply --stat -- "$abs_patch_file"
