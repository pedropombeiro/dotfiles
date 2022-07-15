#!/usr/bin/env bash

YADM_SCRIPTS=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/../scripts" &> /dev/null && pwd )

source "${YADM_SCRIPTS}/colors.sh"

extensions_dir="${HOME}/.config/coc/extensions"
packages=(
  coc-explorer
  coc-go
  coc-homeassistant
  coc-json
  coc-markdownlint
  coc-pyright
  coc-sh
  coc-solargraph
  coc-tsserver
  coc-yaml
)

if [[ $(ls -1 "${extensions_dir}/node_modules" 2>/dev/null | wc -l) -ne ${#packages[@]} ]]; then
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
  if ! command -v npm >/dev/null; then
    type -f asdf >/dev/null 2>&1 || . "${HOME}/.asdf/asdf.sh"
  fi

  npm install ${packages[@]} --global-style --ignore-scripts --no-bin-links --no-package-lock --only=prod
  popd
fi
