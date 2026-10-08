#!/usr/bin/env zsh

YADM_SCRIPTS=$( cd -- "$( dirname -- ${(%):-%x} )/../scripts" &> /dev/null && pwd )

source "${YADM_SCRIPTS}/colors.sh"
(( $+functions[_update_step] )) || _update_step() { : }

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
    printf "${RED}%s${NC}\n" "${label} benchmark failed or produced no median; skipping history update."
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
  local warned=0

  read_benchmark_history "${history_file}"
  history_samples=${#reply[@]}

  printf "Current median startup time: %.0fms\n" $(( benchmark * 1000 ))

  if (( benchmark >= hard_limit )); then
    printf "${RED}%s${NC}\n" "${label} startup time exceeded hard limit ($(printf '%.0f' $(( hard_limit * 1000 )))ms)."
    warned=1
  fi

  if (( history_samples >= baseline_min_samples )); then
    baseline_median="$(benchmark_history_median "${history_file}")"
    if [[ -n "${baseline_median}" ]]; then
      printf "Rolling median (%d prior runs): %.0fms\n" "${history_samples}" $(( baseline_median * 1000 ))
      if (( benchmark >= baseline_median * 1.1 )); then
        printf "${RED}%s${NC}\n" "${label} startup time increased over 10% compared to rolling median."
        warned=1
      fi
    fi
  else
    printf "Collecting baseline (%d/%d prior runs).\n" "${history_samples}" "${baseline_min_samples}"
  fi

  append_benchmark_history "${history_file}" "${benchmark}"
  return ${warned}
}

_update_step "tldr"
printf "${YELLOW}%s${NC}" "Updating tldr... "
tldr --update
echo

_update_step "zinit"
printf "${YELLOW}%s${NC}\n" "Updating zinit and plugins..."
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [[ -f "${ZINIT_HOME}/zinit.zsh" ]]; then
  # Prepend site-functions to fpath before zinit so that when zinit update
  # internally calls compinit, the resulting .zcompdump includes our custom
  # completions (_atuin, _sesh, etc.) and not just zinit-managed ones.
  fpath=($HOME/.config/zsh/site-functions $fpath)
  source "${ZINIT_HOME}/zinit.zsh"
  # Updates run through `script` without interactive input, so never invoke a pager.
  ZINIT[NO_PAGER]=1
  zinit self-update
  zinit update --parallel

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
    printf "${YELLOW}%s${NC}\n" "Re-downloading ${#stripped} snippet(s) with missing files: ${stripped[*]}"
    zinit update --reset --snippets
  }
fi

# Delete dead symlinks in ~/.shellrc — (-@) = broken symlinks (symlinks whose target doesn't exist)
rm -f ~/.shellrc/**/*(-@N)
# Delete all zsh word code files, and regenerate them again
local _zinit_data="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit"
rm -f ~/*.zwc(N) ~/.shellrc/**/*.zwc(N) ${_zinit_data}/**/*.zwc(N)
zsh -i -c 'sleep 5' # Allow time for .zlogin to asynchronously regenerate the .zwc files

echo
printf "${YELLOW}%s${NC}\n" "Build bat theme"
bat cache --build # Ensure any custom themes and syntax definition files are compiled

_update_step "npm"
# Tool upgrades can leave incremental shims pointing at removed plugin paths.
mise reshim --force
printf "${YELLOW}%s${NC}\n" "Updating npm global packages..."
if (( $+commands[npm] )); then
  npm_output="$(npm update -g 2>&1)"
  npm_status=$?
  printf '%s\n' "${npm_output}"
  (( npm_status == 0 )) || exit ${npm_status}

  if [[ "${npm_output}" == *'install scripts blocked because they are not covered by allowScripts'* ]]; then
    printf "${RED}%s${NC}\n" "npm blocked a global package install script. Allow the named package explicitly, then rerun the update."
    exit 1
  fi
fi

_update_step "opencode skills"
printf "${YELLOW}%s${NC}\n" "Updating OpenCode skills..."
"${YADM_SCRIPTS}/sync-work-skills.zsh" --update || exit $?

# After an upgrade to OpenCode 2, drop the cached OpenCode 1 (yargs) completer so
# the next shell regenerates it with `opencode --completions zsh`. Shell startup
# skips this check because `opencode --version` costs ~0.2s.
opencode_completion="${HOME}/.config/zsh/site-functions/_opencode"
if [[ -f ${opencode_completion} && $(<"${opencode_completion}") == *_opencode_yargs_completions* &&
  $(opencode --version 2>/dev/null) == "opencode v"* ]]; then
  rm -f "${opencode_completion}" "${HOME}"/.zcompdump*(N)
fi
unset opencode_completion

_update_step "skill repositories"
printf "${YELLOW}%s${NC}\n" "Updating skill repositories..."
mise bootstrap repos update --yes --skip-dirty "${HOME}/Developer/github.com/pinchtab/pinchtab"
"${YADM_SCRIPTS}/relink-dotfiles.zsh"

_update_step "shell benchmark"
printf "${YELLOW}%s${NC}\n" "Testing shell instantiation performance..."
run_startup_benchmark "Zsh" 0.25 "${HOME}/.cache/zsh/.startup-time-history.txt" \
  --warmup=1 --max-runs 5 'zsh -i -c exit'

_update_step "yazi plugins"
printf "${YELLOW}%s${NC}\n" "Updating yazi plugins..."
# Ensure that there are no local modifications in the Yazi configuration, which would prevent ya pkg from operating
rm -rf ~/.config/yazi/plugins/* ~/.config/yazi/flavors/*
yadm checkout -- ~/.config/yazi/

ya pkg upgrade && \
  printf "\n${GREEN}%s${NC}\n" "Done"

_update_step "git hooks"
printf "${YELLOW}%s${NC}\n" "Configuring dotfiles git hooks..."
# See ~/.agents/docs/hk.md. Write to the yadm repository's config with `git config --file`:
# `yadm enter` passes arguments through `zsh -c`, which breaks the quoting of hook commands.
() {
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

  git config --file "${yadm_config}" hook.check-all.event pre-push
  git config --file "${yadm_config}" hook.check-all.command \
    'check_all() { [ "${HK:-1}" = "0" ] || ! command -v hk >/dev/null 2>&1 || { command -v standardrb >/dev/null 2>&1 || export HK_SKIP_STEPS="${HK_SKIP_STEPS:+$HK_SKIP_STEPS,}standardrb"; cd "$(git rev-parse --show-toplevel)" && hk check --all; }; }; check_all'
} && printf "\n${GREEN}%s${NC}\n" "Done"

_update_step "neovim plugins"
printf "${YELLOW}%s${NC}\n" "Updating neovim plugins..."
nvim --headless '+Lazy! sync' +qa && \
  nvim --headless "+Lazy! build firenvim" +qa && \
  nvim --headless '+MasonToolsUpdateSync' +qa && \
  printf "\n${GREEN}%s${NC}\n" "Done"

_update_step "neovim benchmark"
printf "${YELLOW}%s${NC}\n" "Testing Neovim startup performance..."
migrate_legacy_benchmark_history "${HOME}/.cache/nvim/.startup-time-history.txt" "${HOME}/.cache/nvim/.startup-time.txt"
run_startup_benchmark "Neovim" 0.125 "${HOME}/.cache/nvim/.startup-time-history.txt" \
  --warmup 5 'nvim --headless +qa'

"${YADM_SCRIPTS}/check-configs.zsh"
