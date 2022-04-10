#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source "${SCRIPT_DIR}/../scripts/colors.sh"

extensions_dir="${HOME}/.config/coc/extensions"
packages=(
  coc-go
  coc-json
  coc-markdownlint
  coc-pyright
  coc-sh
  coc-solargraph
  coc-tabnine
  coc-tsserver
  coc-yaml
)

if [[ $(ls -1 "${extensions_dir}/node_modules" | wc -l) -ne ${#packages[@]} ]]; then
  printf "${YELLOW}%s${NC}\n" 'Change in number of Vim CoC plugins detected, repaving...'

  rm -rf "${extensions_dir}" 2>/dev/null || touch "${extensions_dir}/.repave"
fi

if [[ ! -d "${extensions_dir}" || -f "${extensions_dir}/.repave" ]]; then
  rm -f "${extensions_dir}/.repave"

  # Install extensions
  mkdir -p "${extensions_dir}"
  pushd "${extensions_dir}"

  if [ ! -f "${extensions_dir}/package.json" ]; then
    echo '{"dependencies":{}}'> "${extensions_dir}/package.json"
  fi

  printf "${YELLOW}%s${NC}\n" "Installing CoC extensions..."
  npm install ${packages[@]} --global-style --ignore-scripts --no-bin-links --no-package-lock --only=prod
  popd
fi
