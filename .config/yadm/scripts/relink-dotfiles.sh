#!/usr/bin/env bash

class="$(yadm config local.class)"
src_path="${HOME}/Sync/pedro/.dotfiles/Home/MBP.${class}"
if [[ -d ${src_path} ]]; then
  echo "Linking .dotfiles in ${src_path} to ${HOME}..."
  find ~ -type f -name '.*history' -maxdepth 1 -print0 | xargs -0 -n 1 -I {} cp {} "${src_path}/"
  find "${src_path}" -type f -not -name '.sync-conflict*' -maxdepth 1 -print0 | xargs -0 -n 1 -I file bash -c "echo '> file' && ln -sf file ~/"
else
  echo "${src_path} not found. Please configure Syncthing and perform a sync run first."
fi

# Relink ~/.config/pgcli until Mackup starts supporting pgcli
if [[ -d ~/.config/pgcli ]]; then
  if [[ ! -d "${HOME}/Sync/pedro/.dotfiles/Home/MBP.${class}/.config/pgcli" ]]; then
    echo "Copying pgcli config to Syncthing..."
    mkdir -p "${HOME}/Sync/pedro/.dotfiles/Home/MBP.${class}/.config/"
    cp -R ~/.config/pgcli "${HOME}/Sync/pedro/.dotfiles/Home/MBP.${class}/.config/"
  fi

  echo "Linking pgcli config to ${HOME}..."
  find "${HOME}/Sync/pedro/.dotfiles/Home/MBP.${class}/.config/pgcli" -type f -print0 | xargs -0 -n 1 -I {} ln -sf {} ~/.config/pgcli/
fi
