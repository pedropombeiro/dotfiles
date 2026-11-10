#!/usr/bin/env zsh

source "${YADM_SCRIPTS}/lib/startup-benchmark.zsh"

step_zsh_benchmark() {
  run_startup_benchmark "Zsh" 0.25 "${HOME}/.cache/zsh/.startup-time-history.txt" \
    --warmup=1 --max-runs 5 'zsh -i -c exit'
}

_update_register "zsh benchmark" step_zsh_benchmark
