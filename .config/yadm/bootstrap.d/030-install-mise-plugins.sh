#!/usr/bin/env bash

YADM_SCRIPTS=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../scripts" &>/dev/null && pwd)

# shellcheck source=../scripts/colors.sh
source "${YADM_SCRIPTS}/colors.sh"

printf "${YELLOW}%s${NC}\n" "Installing mise plugins..."
(cd ~ && mise install --yes)

printf "${YELLOW}%s${NC}\n" "Cloning configured repositories..."
(cd ~ && mise bootstrap repos apply --yes)

if [[ $(uname -s) != 'Darwin' ]]; then
  if [[ ! -f ${HOME}/.fzf.zsh ]]; then
    printf "${YELLOW}%s${NC}\n" "Installing FZF scripts"
    "$(mise where fzf)/install" --no-update-rc --completion --key-bindings
  fi
fi
