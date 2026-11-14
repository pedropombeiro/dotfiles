#!/usr/bin/env zsh

emulate -LR zsh
setopt null_glob
tests_dir=${0:A:h}
tests=("$tests_dir"/test-*.zsh)
if (( ! ${#tests} )); then
  print -ru2 'No regression suites found'
  exit 1
fi
failed=()
for suite in "${tests[@]}"; do
  print -r -- "RUN: ${suite:t}"
  if zsh -df "$suite"; then
    print -r -- "PASS: ${suite:t}"
  else
    print -ru2 -- "FAIL: ${suite:t} (exit $?)"
    failed+=("${suite:t}")
  fi
done
print -r -- "Summary: $(( ${#tests} - ${#failed} )) passed, ${#failed} failed"
if (( ${#failed} )); then
  printf '  FAIL: %s\n' "${failed[@]}"
  exit 1
fi
