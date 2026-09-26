#!/usr/bin/env zsh
#
# Remove dangling yadm alt symlinks left behind after an alternate is renamed or
# deleted. yadm only prunes links whose base name still has tracked alternates.
#
# A link is removed only when all of these hold:
#   - it is a broken symlink
#   - its target's basename contains `##` (it looked like a yadm alternate)
#   - it sits in a directory that holds at least one tracked yadm file
#
# Pass --dry-run to list the links without removing them.

YADM_SCRIPTS=$( cd -- "$( dirname -- ${(%):-%x} )" &>/dev/null && pwd )

source "${YADM_SCRIPTS}/colors.sh"

dry_run=0
[[ ${1:-} == --dry-run ]] && dry_run=1

# Query the repo with plain git: yadm passthrough commands can trigger
# auto-alt, which would change the links this script inspects, even with
# --dry-run.
repo=$(yadm introspect repo)

# (f) splits on newlines; :h takes the dirname; (u) deduplicates
local -a tracked=( "${(@f)$(git -C "${HOME}" --git-dir="${repo}" --work-tree="${HOME}" ls-files)}" )
local -a dirs=( "${(@u)tracked:h}" )

local -i pruned=0
local dir link target
for dir in "${dirs[@]}"; do
  # N = nullglob, D = include dotfiles, @- = symlinks, -@ = broken symlinks
  for link in "${HOME}/${dir}"/*(ND-@); do
    target=$(readlink "${link}")
    [[ ${target:t} == *'##'* ]] || continue
    if (( dry_run )); then
      printf "${YELLOW}%s${NC}\n" "Would remove dangling alt link: ${link} -> ${target}"
    else
      rm -f "${link}"
      printf "${YELLOW}%s${NC}\n" "Removed dangling alt link: ${link} -> ${target}"
    fi
    (( pruned++ ))
  done
done

(( pruned == 0 )) || (( dry_run )) || printf "${GREEN}%s${NC}\n" "Pruned ${pruned} dangling yadm alt links."
return 0 2>/dev/null || exit 0
