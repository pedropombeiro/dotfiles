#!/usr/bin/env bash

YADM_SCRIPTS=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../scripts" &>/dev/null && pwd)

source "${YADM_SCRIPTS}/colors.sh"

class="$(yadm config local.class)"
if [[ ${class} == 'Personal' || ${class} == 'Work' ]]; then
  src_path="${HOME}/Sync/pedro/.dotfiles/Home/MBP.${class}"
  if [[ -d ${src_path} ]]; then
    printf "${YELLOW}%s${NC}\n" "Linking .dotfiles in ${src_path} to ${HOME}..."
    find ~ -type f -name '.*history' -maxdepth 1 -print0 | xargs -r -0 -n 1 -I {} cp {} "${src_path}/"
    find "${src_path}" -type f -not -name '.sync-conflict*' -maxdepth 1 -print0 | xargs -r -0 -n 1 -I file bash -c "echo '> file' && ln -sf file ~/"
  else
    printf "${RED}%s${NC}\n" "${src_path} not found. Please configure Syncthing and perform a sync run first."
  fi

  # Relink ~/.config/pgcli until Mackup starts supporting pgcli
  if [[ -d ${HOME}/.config/pgcli ]]; then
    if [[ ! -d "${HOME}/Sync/pedro/.dotfiles/Home/MBP.${class}/.config/pgcli" ]]; then
      printf "${YELLOW}%s${NC}\n" "Copying pgcli config to Syncthing..."
      mkdir -p "${HOME}/Sync/pedro/.dotfiles/Home/MBP.${class}/.config/"
      cp -R "${HOME}/.config/pgcli" "${HOME}/Sync/pedro/.dotfiles/Home/MBP.${class}/.config/"
    fi

    printf "${YELLOW}%s${NC}\n" "Linking pgcli state to ${HOME}..."
    ln -sf "${HOME}/Sync/pedro/.dotfiles/Home/MBP.${class}/.config/pgcli/history" "${HOME}/.config/pgcli/"
    ln -sf "${HOME}/Sync/pedro/.dotfiles/Home/MBP.${class}/.config/pgcli/log" "${HOME}/.config/pgcli/"
  fi
fi
