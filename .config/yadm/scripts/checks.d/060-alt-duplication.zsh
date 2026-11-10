#!/usr/bin/env zsh

set -o pipefail
source "${${(%):-%x}:A:h:h}/lib/check-helpers.zsh"

print_op_stay "Checking yadm alternates for duplicated content"
if alt_duplication=$("${YADM_SCRIPTS}/validators/check-alt-duplication.zsh" 2>&1); then
  print_ok
else
  echo
  print_failure "${alt_duplication}"
  any_failed=1
fi
exit "$any_failed"
