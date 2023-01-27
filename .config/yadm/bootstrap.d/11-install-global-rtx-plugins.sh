#!/usr/bin/env bash

type -f rtx >/dev/null 2>&1 || eval "$(rtx activate bash)"

export RTX_MISSING_RUNTIME_BEHAVIOR=autoinstall

rtx global hadolint@latest
rtx global shellcheck@latest

if [[ $(uname -s) != 'Darwin' ]]; then
  rtx global fzf@latest

  if [[ ! -f ${HOME}/.fzf.zsh ]]; then
    printf "${YELLOW}%s${NC}\n" "Installing FZF scripts"
    "$(rtx where fzf)/install" --no-update-rc --completion --key-bindings
  fi
fi

unset RTX_MISSING_RUNTIME_BEHAVIOR
