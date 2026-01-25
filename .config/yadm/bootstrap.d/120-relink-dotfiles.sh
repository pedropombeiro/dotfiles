#!/usr/bin/env bash

YADM_SCRIPTS=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../scripts" &>/dev/null && pwd)

# shellcheck source=../scripts/relink-dotfiles.sh
source "${YADM_SCRIPTS}/relink-dotfiles.sh"
