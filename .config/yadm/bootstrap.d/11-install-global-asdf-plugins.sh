#!/usr/bin/env bash

for p in hadolint shellcheck; do
  asdf plugin add "${p}"
done

asdf install hadolint v2.8.0 && asdf global hadolint v2.8.0
asdf install shellcheck 0.8.0 && asdf global shellcheck 0.8.0

if [[ $(uname -s) != 'Darwin' ]]; then
  asdf plugin add fzf
  asdf install fzf 0.29.0 && asdf global fzf 0.29.0

  if [[ ! -f ${HOME}/.fzf.zsh ]]; then
    printf "${YELLOW}%s${NC}\n" "Installing FZF scripts"
    $(asdf where fzf)/install --no-update-rc --completion --key-bindings
  fi
fi
