#!/usr/bin/env bash

function install-ranger-plugin() {
  local proj="$(basename $1)"
  local target_dir="${HOME}/.config/ranger/plugins/${proj}"
  if [[ ! -d "${target_dir}" ]]; then
    mkdir -p "$(dirname "${target_dir}")"
    git clone "$1" "${target_dir}"
    return 1
  fi
  return 0
}

install-ranger-plugin https://github.com/alexanderjeurissen/ranger_devicons
install-ranger-plugin https://github.com/pedropombeiro/ranger-fzf
install-ranger-plugin https://github.com/laggardkernel/ranger-fzf-marks
install-ranger-plugin https://github.com/maximtrp/ranger-archives
install-ranger-plugin https://github.com/alexanderjeurissen/ranger_devicons

if [[ ! -f "${HOME}/.config/ranger/plugins/autojump.py" ]]; then
  curl -s --fail --location https://raw.githubusercontent.com/fdw/ranger-autojump/main/autojump.py --output "${HOME}/.config/ranger/plugins/autojump.py"
fi
