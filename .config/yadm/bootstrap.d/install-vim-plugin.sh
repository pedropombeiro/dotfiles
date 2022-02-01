#!/usr/bin/env bash

source "${HOME}/.config/yadm/scripts/colors.sh"

function install-vim-plugin() {
  local proj="$(basename $1)"
  local target_dir="${HOME}/.vim/pack/bundle/start/${proj}"
  if [[ ! -d "${target_dir}" ]]; then
    printf "${YELLOW}%s${NC}\n" "Installing $1 vim plugin..."
    mkdir -p "$(dirname "${target_dir}")"
    git clone --depth 1 "$1" "${target_dir}"
    return 1
  fi
  return 0
}

