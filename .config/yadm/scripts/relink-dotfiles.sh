#!/usr/bin/env bash

source "${HOME}/.config/yadm/scripts/colors.sh"

class="$(yadm config local.class)"
if [[ ${class} == 'Personal' || ${class} == 'Work' ]]; then
  src_path="${HOME}/Sync/pedro/.dotfiles/Home/MBP.${class}"
  if [[ -d ${src_path} ]]; then
    printf "${YELLOW}%s${NC}\n" "Linking .dotfiles in ${src_path} to ${HOME}..."
    find ~ -type f -name '.*history' -maxdepth 1 -print0 | xargs -0 -n 1 -I {} cp {} "${src_path}/"
    find "${src_path}" -type f -not -name '.sync-conflict*' -maxdepth 1 -print0 | xargs -0 -n 1 -I file bash -c "echo '> file' && ln -sf file ~/"
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

    printf "${YELLOW}%s${NC}\n" "Linking pgcli config to ${HOME}..."
    find "${HOME}/Sync/pedro/.dotfiles/Home/MBP.${class}/.config/pgcli" -type f -print0 | xargs -0 -n 1 -I {} ln -sf {} "${HOME}/.config/pgcli/"
  fi
fi
