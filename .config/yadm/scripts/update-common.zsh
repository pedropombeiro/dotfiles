#!/usr/bin/env zsh

YADM_SCRIPTS=$( cd -- "$( dirname -- ${(%):-%x} )/../scripts" &> /dev/null && pwd )

source "${YADM_SCRIPTS}/colors.sh"
(( $+functions[_update_step] )) || _update_step() { : }

_update_step "tldr"
printf "${YELLOW}%s${NC}" "Updating tldr... "
tldr --update
echo

_update_step "zinit"
printf "${YELLOW}%s${NC}\n" "Updating zinit and plugins..."
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [[ -f "${ZINIT_HOME}/zinit.zsh" ]]; then
  source "${ZINIT_HOME}/zinit.zsh"
  zinit self-update
  zinit update --parallel
fi

# Delete dead symlinks in ~/.shellrc
find -L ~/.shellrc -type l -exec rm -f {} \;
# Delete all zsh word code files, and regenerate them again
fd -tf '\.zwc$' --max-depth 1 ~/. -x rm -f {}
fd -tf '\.zwc$' ~/.shellrc -x rm -f {}
fd -tf '\.zwc$' "${XDG_DATA_HOME:-${HOME}/.local/share}/zinit" -x rm -f {}
zsh -i -c 'sleep 5' # Allow time for .zlogin to asynchronously regenerate the .zwc files

bat cache --build # Ensure any custom themes and syntax definition files are compiled

_update_step "npm"
printf "${YELLOW}%s${NC}\n" "Updating npm global packages..."
command -v npm >/dev/null && npm update -g

_update_step "opencode skills"
printf "${YELLOW}%s${NC}\n" "Updating OpenCode skills..."
command -v npx >/dev/null && npx skills update

_update_step "shell benchmark"
printf "${YELLOW}%s${NC}\n" "Testing shell instantiation performance..."
hf_file="$(mktemp)"
hyperfine --warmup=1 --max-runs 5 'zsh -i -c exit' --export-json "${hf_file}"
mean_time=$(jq -r '.results[].median' "${hf_file}")
if awk "BEGIN {exit !($mean_time >= 0.6)}"; then
  printf "${RED}%s${NC}\n" "Zsh performance is too slow!"
fi

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
benchmark_filepath="${HOME}/.cache/nvim/.startup-time.txt"

hyperfine --warmup 5 --export-json "${hf_file}" 'nvim --headless +qa'
nvim_benchmark="$(jq -r '.results[].median' "${hf_file}")"

if [[ -f ${benchmark_filepath} ]]; then
  prev_benchmark="$(cat "${benchmark_filepath}")"

  if awk "BEGIN {exit !($nvim_benchmark >= $prev_benchmark * 1.1)}"; then
    printf "${RED}%s${NC}\n" "Neovim startup time increased over 10% compared to previous run..."
  else
    echo "${nvim_benchmark}" > "${benchmark_filepath}"
  fi
  echo "Previous median startup time: $(awk "BEGIN { print $prev_benchmark * 1000 }")ms"
else
  echo "${nvim_benchmark}" > "${benchmark_filepath}"
fi

rm -f "${hf_file}"

"${YADM_SCRIPTS}/check-configs.zsh"
