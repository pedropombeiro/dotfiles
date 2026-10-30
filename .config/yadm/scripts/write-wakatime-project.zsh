#!/usr/bin/env zsh
#
# Write .wakatime-project for a git checkout or linked worktree, named after the
# repository in its origin remote so every worktree reports under one project.
# Removes the file when there is no origin remote.
#
# Usage: write-wakatime-project.zsh [DIR]   (defaults to the current directory)

git_dir=${1:-.}
git_dir=${git_dir:A}

[[ "$(git -C "${git_dir}" rev-parse --show-toplevel 2>/dev/null)" == "${git_dir}" ]] || exit 0

remote_url=$(git -C "${git_dir}" remote get-url origin 2>/dev/null) || { rm -f "${git_dir}/.wakatime-project"; exit 0; }
project_name=${remote_url#*gitlab.com/}
project_name=${project_name#*gitlab.com:}
project_name=${project_name%.git}
project_name=${project_name##*/}

[[ -n "${project_name}" ]] || exit 0

echo "${project_name}" > "${git_dir}/.wakatime-project"

# Linked worktrees have a .git file, so ask Git for the shared exclude path.
exclude_file=$(git -C "${git_dir}" rev-parse --path-format=absolute --git-path info/exclude 2>/dev/null)
if [[ -f "${exclude_file}" ]] && ! grep -q '^\.wakatime-project$' "${exclude_file}"; then
  echo '.wakatime-project' >> "${exclude_file}"
fi
