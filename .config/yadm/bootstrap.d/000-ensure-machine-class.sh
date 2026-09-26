#!/usr/bin/env bash

YADM_SCRIPTS=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../scripts" &>/dev/null && pwd)

# shellcheck source=../scripts/colors.sh
source "${YADM_SCRIPTS}/colors.sh"

VALID_CLASSES="Personal Work NAS"

class="$(yadm config --get local.class)"
if [[ " ${VALID_CLASSES} " != *" ${class} "* ]] || [[ -z "${class}" ]]; then
  printf "${RED}%s${NC}\n" "Configure machine class using 'yadm config local.class CLASS' (where CLASS is one of: ${VALID_CLASSES}) and run 'yadm bootstrap' again. Aborting!"
  exit 1
fi
