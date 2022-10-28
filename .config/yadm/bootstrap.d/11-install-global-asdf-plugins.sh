#!/usr/bin/env bash

type -f asdf >/dev/null 2>&1 || . "${HOME}/.asdf/asdf.sh"

for p in hadolint shellcheck; do
  asdf plugin add "${p}"
done

asdf install hadolint 2.10.0 && asdf global hadolint 2.10.0
asdf install shellcheck 0.8.0 && asdf global shellcheck 0.8.0

if [[ $(uname -s) != 'Darwin' ]]; then
  asdf plugin add fzf
  asdf install fzf 0.30.0 && asdf global fzf 0.30.0

  if [[ ! -f ${HOME}/.fzf.zsh ]]; then
    printf "${YELLOW}%s${NC}\n" "Installing FZF scripts"
    $(asdf where fzf)/install --no-update-rc --completion --key-bindings
  fi
fi
