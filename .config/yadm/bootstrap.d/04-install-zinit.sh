#!/usr/bin/env bash

YADM_SCRIPTS=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../scripts" &>/dev/null && pwd)

# shellcheck source=../scripts/colors.sh
source "${YADM_SCRIPTS}/colors.sh"

type -f mise >/dev/null 2>&1 || eval "$(mise activate bash)"

grep '.bash_profile.shared' "${HOME}/.bash_profile" >/dev/null 2>&1 || echo "source ~/.bash_profile.shared" >>"${HOME}/.bash_profile"
grep '.bashrc.shared' "${HOME}/.bashrc" >/dev/null 2>&1 || echo "source ~/.bashrc.shared" >>"${HOME}/.bashrc"

ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

if [[ ! -d "$ZINIT_HOME" ]]; then
  printf "${YELLOW}%s${NC}\n" "Installing zinit..."
  mkdir -p "$(dirname "$ZINIT_HOME")"
  git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# Create minimal .zshrc if it doesn't exist
if [[ ! -f "${HOME}/.zshrc" ]]; then
  echo "source ~/.zshrc.shared" >"${HOME}/.zshrc"
fi
