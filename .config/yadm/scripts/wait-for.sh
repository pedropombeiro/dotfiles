#!/usr/bin/env bash
#
# Shared by bootstrap checkpoints that wait for a manual step.
#
# wait_for DESCRIPTION INSTRUCTIONS COMMAND...
# Re-runs COMMAND until it succeeds, printing INSTRUCTIONS and prompting between
# attempts. Returns 1 when the user skips the check, or when there is no
# terminal to prompt on.

# shellcheck source=./colors.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/colors.sh"

wait_for() {
  local description=$1 instructions=$2 answer
  shift 2
  until "$@" >/dev/null 2>&1; do
    if [[ ! -t 0 ]]; then
      printf "${RED}%s${NC}\n" "${description} is not ready, and there is no terminal to wait on: ${instructions}"
      return 1
    fi
    printf "${YELLOW}%s${NC}\n" "${description} is not ready. ${instructions}"
    read -r -p "Press Enter to check again, or type 's' to skip: " answer
    if [[ ${answer} == [sS]* ]]; then
      printf "${YELLOW}%s${NC}\n" "Skipping: ${description}"
      return 1
    fi
  done
  printf "${GREEN}%s${NC}\n" "${description} is ready"
}
