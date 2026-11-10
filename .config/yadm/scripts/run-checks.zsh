#!/usr/bin/env zsh

set -o pipefail

YADM_SCRIPTS=${${(%):-%x}:A:h}
source "${YADM_SCRIPTS}/lib/check-helpers.zsh"

# YADM selects applicable alternates. Never execute the ## source files.
checks_dir="${YADM_SCRIPTS}/checks.d"
checks=("${checks_dir}"/*.zsh(N))
checks=("${(@)checks:#*\#\#*}")
if (( ${#checks} == 0 )); then
  print_failure "No health checks found in ${checks_dir}; run yadm alt first"
  any_failed=1
fi

for check in "${checks[@]}"; do
  if [[ ! -f "$check" || ! -x "$check" ]]; then
    print_failure "Health check is not a regular executable file: ${check}"
    any_failed=1
    continue
  fi
  if "$check"; then
    continue
  else
    check_rc=$?
    print_failure "Health check ${check:t} failed (exit ${check_rc})"
    any_failed=1
  fi
done

if (( any_failed )); then
  printf "${YELLOW}%s${NC}\n" "⚠️  Checks finished with errors/warnings!"
  exit 1
fi
printf "${GREEN}%s${NC}\n" "✅ Checks finished!"
