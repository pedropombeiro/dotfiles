#!/usr/bin/env bash

YADM_SCRIPTS=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/../scripts" &> /dev/null && pwd )

source "${YADM_SCRIPTS}/colors.sh"

function install-vim-plugin() {
  local url="$1"
  local branch=''
  if [[ $url == *"@"* ]]; then
    url="$(echo "$1" | cut -d'@' -f1)"
    branch="$(echo "$1" | cut -d'@' -f2)"
  fi

  local proj="$(basename "${url}")"
  local target_dir="${HOME}/.vim/pack/bundle/start/${proj}"
  if [[ ! -d "${target_dir}" ]]; then
    mkdir -p "$(dirname "${target_dir}")"
    if [[ -z $branch ]]; then
      printf "${YELLOW}%s${NC}\n" "Installing ${url} vim plugin..."
      git clone --depth 1 "$1" "${target_dir}"
    else
      printf "${YELLOW}%s${NC}\n" "Installing ${url} vim plugin (branch: ${branch})..."
      git clone --branch "${branch}" --depth 1 "${url}" "${target_dir}"
    fi
    return 1
  fi
  return 0
}

