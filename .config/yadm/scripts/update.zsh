#!/usr/bin/env zsh

set -o pipefail
YADM_SCRIPTS=${${(%):-%x}:A:h}
source "${YADM_SCRIPTS}/lib/update-runner.zsh"

# Load and validate the complete workflow before logs, sudo, or live updates.
_update_load_modules "${YADM_SCRIPTS}/updates.d" || exit 1
source "${YADM_SCRIPTS}/lib/update-ui.zsh"
_update_execute
