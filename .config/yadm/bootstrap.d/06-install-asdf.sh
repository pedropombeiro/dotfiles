#!/usr/bin/env bash

set +e
for p in golang golangci-lint hadolint nodejs yarn ruby shellcheck; do
  asdf plugin add "${p}"
done
asdf install golang 1.13.8 && asdf global golang 1.13.8
asdf install golangci-lint 1.27.0 && asdf global golangci-lint 1.27.0
echo "hadolint shellcheck" | xargs -n 1 -I R bash -c 'asdf install R latest && asdf global R latest'

bash -c '${ASDF_DATA_DIR:=$HOME/.asdf}/plugins/nodejs/bin/import-release-team-keyring'
asdf install nodejs 14.5.0 && asdf global nodejs 14.5.0
asdf install yarn 1.22.4 && asdf global yarn 1.22.4

asdf install ruby 2.7.4 && asdf global ruby 2.7.4
set -e
