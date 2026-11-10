#!/usr/bin/env zsh

source "${YADM_SCRIPTS}/lib/startup-benchmark.zsh"

step_neovim_plugins() {
  nvim --headless '+Lazy! sync' +qa
  nvim --headless "+Lazy! build firenvim" +qa
  nvim --headless '+MasonToolsUpdateSync' +qa
}

step_neovim_benchmark() {
  migrate_legacy_benchmark_history "${HOME}/.cache/nvim/.startup-time-history.txt" "${HOME}/.cache/nvim/.startup-time.txt"
  run_startup_benchmark "Neovim" 0.125 "${HOME}/.cache/nvim/.startup-time-history.txt" \
    --warmup 5 'nvim --headless +qa'
}

_update_register "neovim plugins" step_neovim_plugins
_update_register "neovim benchmark" step_neovim_benchmark
