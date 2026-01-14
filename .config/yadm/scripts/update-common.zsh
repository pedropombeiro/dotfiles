#!/usr/bin/env zsh

YADM_SCRIPTS=$( cd -- "$( dirname -- ${(%):-%x} )/../scripts" &> /dev/null && pwd )

source "${YADM_SCRIPTS}/colors.sh"

printf "${YELLOW}%s${NC}" "Updating tldr... "
tldr --update
echo

# Update Oh-my-zsh custom themes and plugins
DISABLE_AUTO_UPDATE=true source "${HOME}/.oh-my-zsh/oh-my-zsh.sh"
omz update
find "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/themes" -mindepth 1 -maxdepth 1 -type d -print0 | \
  xargs -r -0 -P 8 -I {} git -C {} pull --prune --stat -v --ff-only
find "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins" -mindepth 1 -maxdepth 1 -type d -print0 | \
  xargs -r -0 -P 8 -I {} git -C {} pull --prune --stat -v --ff-only

# Delete dead symlinks in ~/.shellrc
find -L ~/.shellrc -type l -exec rm -f {} \;
# Delete all zsh word code files, and regenerate them again
find ~/. -maxdepth 1 -name '*.zwc' -delete
find ~/.shellrc -name '*.zwc' -delete
find ~/.oh-my-zsh -name '*.zwc' -delete
zsh -i -c 'sleep 5' # Allow time for .zlogin to asynchronously regenerate the .zwc files

bat cache --build # Ensure any custom themes and syntax definition files are compiled

# Update npm packages
printf "${YELLOW}%s${NC}\n" "Updating npm global packages..."
command -v npm >/dev/null && npm update -g

printf "${YELLOW}%s${NC}\n" "Testing shell instantiation performance..."
hf_file="$(mktemp)"
hyperfine --warmup=1 --max-runs 5 'zsh -i -c exit' --export-json "${hf_file}"
mean_time=$(jq -r '.results[].median' "${hf_file}")
if awk "BEGIN {exit !($mean_time >= 0.6)}"; then
  printf "${RED}%s${NC}\n" "Zsh performance is too slow!"
fi

printf "${YELLOW}%s${NC}\n" "Updating yazi plugins..."
# Ensure that there are no local modifications in the Yazi configuration, which would prevent ya pkg from operating
rm -rf ~/.config/yazi/plugins/* ~/.config/yazi/flavors/*
yadm checkout -- ~/.config/yazi/

ya pkg upgrade && \
  printf "\n${GREEN}%s${NC}\n" "Done"

printf "${YELLOW}%s${NC}\n" "Installing pre-commit hooks..."
yadm enter pre-commit install --install-hooks 2>/dev/null || true

printf "${YELLOW}%s${NC}\n" "Updating neovim plugins..."
nvim --headless '+Lazy! sync' +qa && \
  nvim --headless "+Lazy! build firenvim" +qa && \
  printf "\n${GREEN}%s${NC}\n" "Done"

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
