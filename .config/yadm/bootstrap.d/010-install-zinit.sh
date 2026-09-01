#!/usr/bin/env bash

type -f mise >/dev/null 2>&1 || eval "$(mise activate bash)"

mise bootstrap --only repos --skip-dirty --yes

grep '.bash_profile.shared' "${HOME}/.bash_profile" >/dev/null 2>&1 || echo "source ~/.bash_profile.shared" >>"${HOME}/.bash_profile"
grep '.bashrc.shared' "${HOME}/.bashrc" >/dev/null 2>&1 || echo "source ~/.bashrc.shared" >>"${HOME}/.bashrc"

# Create minimal .zshrc if it doesn't exist
if [[ ! -f "${HOME}/.zshrc" ]]; then
  echo "source ~/.zshrc.shared" >"${HOME}/.zshrc"
fi
