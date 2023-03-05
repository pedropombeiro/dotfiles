#!/usr/bin/env bash

YADM_SCRIPTS=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../scripts" &>/dev/null && pwd)

source "${YADM_SCRIPTS}/colors.sh"

printf "${YELLOW}%s${NC}\n" "Installing rtx plugins..."
(cd ~ && rtx install --install-missing)

if [[ $(uname -s) != 'Darwin' ]]; then
  if [[ ! -f ${HOME}/.fzf.zsh ]]; then
    printf "${YELLOW}%s${NC}\n" "Installing FZF scripts"
    "$(rtx where fzf)/install" --no-update-rc --completion --key-bindings
  fi
fi
