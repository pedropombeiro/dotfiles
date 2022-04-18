#!/usr/bin/env bash

for p in fzf hadolint shellcheck; do
  asdf plugin add "${p}"
done

asdf install fzf 0.29.0 && asdf global fzf 0.29.0
asdf install hadolint v2.8.0 && asdf global hadolint v2.8.0
asdf install shellcheck 0.8.0 && asdf global shellcheck 0.8.0
