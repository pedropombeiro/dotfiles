#!/usr/bin/env zsh

YADM_SCRIPTS=$( cd -- "$( dirname -- ${(%):-%x} )/../scripts" &> /dev/null && pwd )

(( $+functions[_update_init] )) || source "${YADM_SCRIPTS}/update-ui.zsh"

is_benchmark_value() {
  [[ "$1" =~ '^[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?$' ]]
}

# Sets `reply` to the valid samples in a history file, skipping entries such as
# `null` that an unparsable benchmark export left behind.
read_benchmark_history() {
  local history_file="$1"
  local line

  reply=()
  [[ -f "${history_file}" ]] || return 0

  while IFS= read -r line; do
    is_benchmark_value "${line}" && reply+=("${line}")
  done < "${history_file}"
}

# Prints the median wall-clock time in seconds from a hyperfine JSON export.
# Hyperfine 2 moved the statistics under `summary.<metric>`; 1.x keeps them at
# the top level of each result.
hyperfine_median() {
  local median

  median="$(jq -er '.results[0] | (.summary.time_wall_clock.median // .median) | numbers' "$1" 2>/dev/null)" || return 1
  is_benchmark_value "${median}" || return 1
  printf '%s\n' "${median}"
}

# Benchmarks a command and reports its median startup time against the history.
run_startup_benchmark() {
  local label="$1"
  local hard_limit="$2"
  local history_file="$3"
  shift 3
  local export_file
  local median

  export_file="$(mktemp)"
  if hyperfine "$@" --export-json "${export_file}" && median="$(hyperfine_median "${export_file}")"; then
    report_benchmark "${label}" "${median}" "${hard_limit}" "${history_file}"
  else
    _update_warn "${label} benchmark failed or produced no median; skipping history update."
  fi
  rm -f "${export_file}"
}

benchmark_history_median() {
  local history_file="$1"
  local max_samples="${2:-10}"
  local count=0
  local values=()

  read_benchmark_history "${history_file}"
  values=("${reply[@]}")

  count=${#values[@]}
  (( count > 0 )) || return 1

  if (( count > max_samples )); then
    values=("${values[@]: -max_samples}")
    count=${#values[@]}
  fi

  printf '%s\n' "${values[@]}" | python3 -c 'import statistics, sys; values = [float(line.strip()) for line in sys.stdin if line.strip()]; print(statistics.median(values))'
}

append_benchmark_history() {
  local history_file="$1"
  local benchmark="$2"
  local max_samples="${3:-10}"
  local history_dir="${history_file:h}"
  local values=()

  mkdir -p "${history_dir}"

  read_benchmark_history "${history_file}"
  values=("${reply[@]}")

  values+=("${benchmark}")

  if (( ${#values[@]} > max_samples )); then
    values=("${values[@]: -max_samples}")
  fi

  printf '%s\n' "${values[@]}" > "${history_file}"
}

migrate_legacy_benchmark_history() {
  local history_file="$1"
  local legacy_file="$2"

  [[ -f "${legacy_file}" ]] || return 0
  [[ -f "${history_file}" ]] && return 0

  mkdir -p "${history_file:h}"
  cp "${legacy_file}" "${history_file}"
}

report_benchmark() {
  local label="$1"
  local benchmark="$2"
  local hard_limit="$3"
  local history_file="$4"
  local baseline_min_samples="${5:-5}"
  local history_samples=0
  local baseline_median
  local note

  read_benchmark_history "${history_file}"
  history_samples=${#reply[@]}

  note=$(printf 'median %.0fms' $(( benchmark * 1000 )))

  if (( benchmark >= hard_limit )); then
    _update_warn "${label} startup time exceeded hard limit ($(printf '%.0f' $(( hard_limit * 1000 )))ms)."
  fi

  if (( history_samples >= baseline_min_samples )); then
    baseline_median="$(benchmark_history_median "${history_file}")"
    if [[ -n "${baseline_median}" ]]; then
      note+=$(printf ', rolling median %.0fms over %d runs' $(( baseline_median * 1000 )) "${history_samples}")
      if (( benchmark >= baseline_median * 1.1 )); then
        _update_warn "${label} startup time increased over 10% compared to rolling median."
      fi
    fi
  else
    note+=$(printf ', collecting baseline (%d/%d runs)' "${history_samples}" "${baseline_min_samples}")
  fi

  _update_note "${note}"
  append_benchmark_history "${history_file}" "${benchmark}"
}

step_tldr() {
  tldr --update
}

step_zinit() {
  # zinit's own code expects failing commands not to abort it, so check its
  # results explicitly instead of relying on ERR_RETURN.
  setopt local_options no_err_return

  ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
  [[ -f "${ZINIT_HOME}/zinit.zsh" ]] || return 0

  # Prepend site-functions to fpath before zinit so that when zinit update
  # internally calls compinit, the resulting .zcompdump includes our custom
  # completions (_atuin, _sesh, etc.) and not just zinit-managed ones.
  fpath=($HOME/.config/zsh/site-functions $fpath)
  source "${ZINIT_HOME}/zinit.zsh" || return
  # Updates run without interactive input, so never invoke a pager.
  ZINIT[NO_PAGER]=1
  zinit self-update || return
  zinit update --parallel || return

  # Self-heal stripped snippets. Before re-extracting, zinit moves a snippet's
  # existing files into ._backup and only restores them on a *handled* failure,
  # so an update killed in between leaves the directory holding just ._zinit
  # metadata (and possibly a stale .zwc). Unlike plugins, which are git clones
  # that recover on the next update, single-file snippets stay broken and every
  # new shell then reports "Snippet not loaded (...)". Detect the empty ones and
  # force a re-download.
  () {
    setopt local_options extended_glob
    local dir
    local -a stripped payload
    for dir in ${ZINIT[SNIPPETS_DIR]:-${HOME}/.local/share/zinit/snippets}/**/._zinit(N/); do
      dir="${dir:h}"
      payload=( ${dir}/*~*.zwc(.N) )
      (( ${#payload} )) || stripped+=("${dir:t}")
    done
    (( ${#stripped} )) || return 0
    _update_note "re-downloaded ${#stripped} snippet(s) with missing files: ${stripped[*]}"
    zinit update --reset --snippets
  } || return
}

step_zsh_bytecode() {
  local zinit_data="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit"
  local file
  local -a pending
  local -i i

  # Delete dead symlinks in ~/.shellrc — (-@) = broken symlinks (symlinks whose target doesn't exist)
  rm -f ~/.shellrc/**/*(-@N)
  # Delete all zsh word code files, and regenerate them again
  rm -f ~/*.zwc(N) ~/.*.zwc(N) ~/.shellrc/**/*.zwc(N) ${zinit_data}/**/*.zwc(N)

  # Interactive startup compiles the files it sources. Only a login shell reads
  # .zlogin, which compiles .zshrc, .zcompdump, and zinit plugins in a
  # background job, so wait for the zinit files (up to 5s) instead of sleeping.
  zsh -il -c exit
  for (( i = 0; i < 50; i++ )); do
    # (.L+0) = non-empty regular files; .zlogin's zcompare skips empty ones.
    # Test in a loop: an `e` glob qualifier ends the step under ERR_RETURN.
    pending=()
    for file in ${zinit_data}/**/*.zsh(.L+0N); do
      [[ -s ${file}.zwc ]] || pending+=("${file}")
    done
    (( ${#pending} )) || return 0
    zselect -t 10 || true # Exits 1 on timeout, which is the point here
  done
  _update_warn "${#pending} zinit file(s) still had no .zwc after 5s; the next login shell compiles them."
}

step_bat() {
  bat cache --build # Ensure any custom themes and syntax definition files are compiled
}

step_npm() {
  local output
  local -i rc=0

  # Tool upgrades can leave incremental shims pointing at removed plugin paths.
  mise reshim --force
  (( $+commands[npm] )) || return 0

  output="$(npm update -g 2>&1)" || rc=$?
  print -r -- "${output}"
  (( rc == 0 )) || return ${rc}

  if [[ "${output}" == *'install scripts blocked because they are not covered by allowScripts'* ]]; then
    print -r -- "npm blocked a global package install script. Allow the named package explicitly, then rerun the update."
    return 1
  fi
}

step_opencode_skills() {
  local opencode_completion="${HOME}/.config/zsh/site-functions/_opencode"

  "${YADM_SCRIPTS}/sync-work-skills.zsh" --update

  # After an upgrade to OpenCode 2, drop the cached OpenCode 1 (yargs) completer so
  # the next shell regenerates it with `opencode --completions zsh`. Shell startup
  # skips this check because `opencode --version` costs ~0.2s.
  if [[ -f ${opencode_completion} && $(<"${opencode_completion}") == *_opencode_yargs_completions* &&
    $(opencode --version 2>/dev/null) == "opencode v"* ]]; then
    rm -f "${opencode_completion}" "${HOME}"/.zcompdump*(N)
  fi
}

# Upgrades can leave the running service unable to reach the collector, which
# OpenCode doesn't report. Restarts the service when only its launch context fails.
step_opencode_telemetry() {
  "${YADM_SCRIPTS}/check-opencode-telemetry.zsh" --fix
}

step_skill_repositories() {
  mise bootstrap repos update --yes --skip-dirty "${HOME}/Developer/github.com/pinchtab/pinchtab"
  "${YADM_SCRIPTS}/relink-dotfiles.zsh"
}

step_zsh_benchmark() {
  run_startup_benchmark "Zsh" 0.25 "${HOME}/.cache/zsh/.startup-time-history.txt" \
    --warmup=1 --max-runs 5 'zsh -i -c exit'
}

step_yazi() {
  # Ensure that there are no local modifications in the Yazi configuration, which would prevent ya pkg from operating
  rm -rf ~/.config/yazi/plugins/* ~/.config/yazi/flavors/*
  yadm checkout -- ~/.config/yazi/
  ya pkg upgrade
}

# See ~/.agents/docs/hk.md. Write to the yadm repository's config with `git config --file`:
# `yadm enter` passes arguments through `zsh -c`, which breaks the quoting of hook commands.
step_git_hooks() {
  local repo yadm_config event
  repo=$(yadm introspect repo)
  yadm_config="${repo}/config"

  # Superseded by hk. Keep the script for review instead of deleting it.
  if grep -qs 'File generated by pre-commit' "${repo}/hooks/pre-commit"; then
    mv "${repo}/hooks/pre-commit" "${repo}/hooks/pre-commit.pre-commit-framework.bak"
  fi

  # Machines with the global hk hooks already run them in this repository.
  if ! git config --global --get hook.hk-pre-commit.command >/dev/null; then
    for event in pre-commit commit-msg; do
      git config --file "${yadm_config}" "hook.hk-${event}.event" "${event}"
      git config --file "${yadm_config}" "hook.hk-${event}.command" \
        "{ [ \"\${HK:-1}\" = \"0\" ] || ! command -v hk >/dev/null 2>&1 ; } || hk run ${event} --from-hook \"\$@\""
    done
  fi

  # Replace the full working-tree check with hk's outgoing-file selection.
  git config --file "${yadm_config}" --remove-section hook.check-all 2>/dev/null || true
  git config --file "${yadm_config}" hook.check-push.event pre-push
  git config --file "${yadm_config}" hook.check-push.command \
    'check_push() { [ "${HK:-1}" = "0" ] || ! command -v hk >/dev/null 2>&1 || { command -v standardrb >/dev/null 2>&1 || export HK_SKIP_STEPS="${HK_SKIP_STEPS:+$HK_SKIP_STEPS,}standardrb"; cd "$(git rev-parse --show-toplevel)" && hk run pre-push --from-hook "$@"; }; }; check_push "$@"'
}

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

step_config_checks() {
  "${YADM_SCRIPTS}/check-configs.zsh"
}

_step "tldr" step_tldr
_step "zinit" step_zinit
_step "zsh bytecode" step_zsh_bytecode
_step "bat theme" step_bat
_step "npm" step_npm
_step "opencode skills" step_opencode_skills
_step "opencode telemetry" step_opencode_telemetry
_step "skill repositories" step_skill_repositories
_step "zsh benchmark" step_zsh_benchmark
_step "yazi plugins" step_yazi
_step "git hooks" step_git_hooks
_step "neovim plugins" step_neovim_plugins
_step "neovim benchmark" step_neovim_benchmark
_step "config checks" step_config_checks
