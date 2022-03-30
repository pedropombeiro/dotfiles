#!/usr/bin/env bash

YADM_SCRIPTS=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/../scripts" &> /dev/null && pwd )

source "${YADM_SCRIPTS}/colors.sh"

if [ -z "$(yadm config --get local.class)" ]; then
  printf "${RED}%s${NC}\n" "Configure machine class using 'yadm config local.class CLASS' (where CLASS is Personal or Work) and run 'yadm bootstrap' again. Aborting!"
  exit 1
fi
