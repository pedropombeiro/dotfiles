#!/usr/bin/env zsh

set -o pipefail
setopt EXTENDED_GLOB
source "${${(%):-%x}:A:h:h}/lib/check-helpers.zsh"

# A vendored skill removed from disk without updating .skill-lock.json gets
# silently reinstalled on the next skill update. Work-only skills live in
# ~/.agents/skills.work and are expected to be absent on non-Work machines.
function check_skill_lock_orphans() {
  print_op_stay "Checking .skill-lock.json entries have directories"

  local lock="$HOME/.agents/.skill-lock.json"
  if [[ ! -f "$lock" ]]; then
    print_ok "(skipped, no lock file)"
    return
  fi

  source "${YADM_SCRIPTS}/lib/work-skills.zsh"
  local class=$(yadm config local.class 2>/dev/null)

  local -a orphans
  local s dir
  for s in ${(f)"$(jq -r '.skills | keys[]' "$lock" 2>/dev/null)"}; do
    [[ -z "$s" ]] && continue
    if (( ${work_skills[(Ie)$s]} )); then
      [[ "$class" == Work ]] || continue
      dir="$HOME/.agents/skills.work/$s"
    else
      dir="$HOME/.agents/skills/$s"
    fi
    [[ -d "$dir" ]] || orphans+=("$s")
  done

  # The reverse (a directory with no lock entry) is normal: hand-authored
  # skills are never in the lock file.
  if (( ${#orphans} == 0 )); then
    print_ok
  else
    echo
    for s in "${orphans[@]}"; do
      print_warn "$s in .skill-lock.json but not installed"
    done
  fi
}

check_skill_lock_orphans
exit "$any_failed"
