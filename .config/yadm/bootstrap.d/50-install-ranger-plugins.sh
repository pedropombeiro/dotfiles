#!/usr/bin/env bash

YADM_SCRIPTS=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/../scripts" &> /dev/null && pwd )

source "${YADM_SCRIPTS}/colors.sh"

plugins_dir="${HOME}/.config/ranger/plugins"

function install-ranger-plugin() {
  local proj="$(basename $1)"
  local target_dir="${plugins_dir}/${proj}"
  if [[ ! -d "${target_dir}" ]]; then
    mkdir -p "$(dirname "${target_dir}")"
    git clone "$1" "${target_dir}"
    return 1
  fi
  return 0
}

urls=(
  'https://github.com/alexanderjeurissen/ranger_devicons'
  'https://github.com/laggardkernel/ranger-fzf-marks'
  'https://github.com/maximtrp/ranger-archives'
  'https://github.com/pedropombeiro/ranger-fzf'
)
if [[ $(find "${plugins_dir}" -mindepth 1 -maxdepth 1 -type d -not -name '__*' | wc -l) -ne ${#urls[@]} ]]; then
  printf "${YELLOW}%s${NC}\n" 'Change in number of Ranger plugins detected, repaving...'

  rm -rf "${plugins_dir}"
fi

for url in ${urls[@]}; do
  install-ranger-plugin "${url}"
done

if [[ ! -f "${HOME}/.config/ranger/plugins/autojump.py" ]]; then
  curl -s --fail --location https://raw.githubusercontent.com/fdw/ranger-autojump/main/autojump.py --output "${plugins_dir}/autojump.py"
fi
