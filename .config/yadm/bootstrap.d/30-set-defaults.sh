#!/usr/bin/env bash

YADM_SCRIPTS=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../scripts" &>/dev/null && pwd)

# shellcheck source=../scripts/defaults.sh
[[ -f ${YADM_SCRIPTS}/defaults.sh ]] && source "${YADM_SCRIPTS}/defaults.sh" || exit 0
