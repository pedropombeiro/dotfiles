#!/usr/bin/env bash

type -f asdf >/dev/null 2>&1 || . "${HOME}/.asdf/asdf.sh"

for p in hadolint shellcheck shfmt stylua; do
  asdf plugin add "${p}"
done

asdf install hadolint latest && asdf global hadolint latest
asdf install shellcheck latest && asdf global shellcheck latest
asdf install shfmt latest && asdf global shfmt latest
asdf install stylua latest && asdf global stylua latest

if [[ $(uname -s) != 'Darwin' ]]; then
  asdf plugin add fzf
  asdf install fzf latest && asdf global fzf latest

  if [[ ! -f ${HOME}/.fzf.zsh ]]; then
    printf "${YELLOW}%s${NC}\n" "Installing FZF scripts"
    "$(asdf where fzf)/install" --no-update-rc --completion --key-bindings
  fi
fi
