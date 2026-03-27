#!/usr/bin/env zsh

YADM_SCRIPTS=$( cd -- "$( dirname -- ${(%):-%x} )/../scripts" &> /dev/null && pwd )

source "${YADM_SCRIPTS}/colors.sh"
(( $+functions[_update_step] )) || _update_step() { : }

benchmark_history_median() {
  local history_file="$1"
  local max_samples="${2:-10}"
  local count=0
  local line
  local values=()

  if [[ -f "${history_file}" ]]; then
    while IFS= read -r line; do
      [[ -n "${line}" ]] || continue
      values+=("${line}")
    done < "${history_file}"
  fi

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
  local line
  local values=()

  mkdir -p "${history_dir}"

  if [[ -f "${history_file}" ]]; then
    while IFS= read -r line; do
      [[ -n "${line}" ]] || continue
      values+=("${line}")
    done < "${history_file}"
  fi

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
  local line
  local baseline_median
  local warned=0

  if [[ -f "${history_file}" ]]; then
    while IFS= read -r line; do
      [[ -n "${line}" ]] || continue
      (( history_samples += 1 ))
    done < "${history_file}"
  fi

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
        printf "${RED}%s${NC}\n" "${label} startup time increased over 10%% compared to rolling median."
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
  zinit self-update
  zinit update --parallel
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
printf "${YELLOW}%s${NC}\n" "Updating npm global packages..."
(( $+commands[npm] )) && npm update -g

_update_step "opencode skills"
printf "${YELLOW}%s${NC}\n" "Updating OpenCode skills..."
(( $+commands[npx] )) && npx skills update

_update_step "shell benchmark"
printf "${YELLOW}%s${NC}\n" "Testing shell instantiation performance..."
hf_file="$(mktemp)"
hyperfine --warmup=1 --max-runs 5 'zsh -i -c exit' --export-json "${hf_file}"
mean_time=$(jq -r '.results[].median' "${hf_file}")
report_benchmark "Zsh" "${mean_time}" 0.25 "${HOME}/.cache/zsh/.startup-time-history.txt"

_update_step "yazi plugins"
printf "${YELLOW}%s${NC}\n" "Updating yazi plugins..."
# Ensure that there are no local modifications in the Yazi configuration, which would prevent ya pkg from operating
rm -rf ~/.config/yazi/plugins/* ~/.config/yazi/flavors/*
yadm checkout -- ~/.config/yazi/

ya pkg upgrade && \
  printf "\n${GREEN}%s${NC}\n" "Done"

_update_step "pre-commit"
printf "${YELLOW}%s${NC}\n" "Installing pre-commit hooks..."
yadm enter pre-commit install --install-hooks 2>/dev/null || true

_update_step "neovim plugins"
printf "${YELLOW}%s${NC}\n" "Updating neovim plugins..."
nvim --headless '+Lazy! sync' +qa && \
  nvim --headless "+Lazy! build firenvim" +qa && \
  printf "\n${GREEN}%s${NC}\n" "Done"

_update_step "neovim benchmark"
printf "${YELLOW}%s${NC}\n" "Testing Neovim startup performance..."
migrate_legacy_benchmark_history "${HOME}/.cache/nvim/.startup-time-history.txt" "${HOME}/.cache/nvim/.startup-time.txt"
hyperfine --warmup 5 --export-json "${hf_file}" 'nvim --headless +qa'
nvim_benchmark="$(jq -r '.results[].median' "${hf_file}")"
report_benchmark "Neovim" "${nvim_benchmark}" 0.125 "${HOME}/.cache/nvim/.startup-time-history.txt"

rm -f "${hf_file}"

"${YADM_SCRIPTS}/check-configs.zsh"
