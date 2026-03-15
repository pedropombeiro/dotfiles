#!/usr/bin/env zsh

setopt LOCAL_OPTIONS EXTENDED_GLOB

# ${(%):-%x} = zsh equivalent of bash's ${BASH_SOURCE[0]}
YADM_SCRIPTS=$(cd -- "$(dirname -- "${(%):-%x}")/../scripts" &>/dev/null && pwd)

source "${YADM_SCRIPTS}/colors.sh"

class="$(yadm config local.class)"
if [[ ${class} == 'Personal' || ${class} == 'Work' ]]; then
  src_path="${HOME}/Sync/pedro/.dotfiles/Home/MBP.${class}"
  if [[ -d ${src_path} ]]; then
    printf "${YELLOW}%s${NC}\n" "Linking .dotfiles in ${src_path} to ${HOME}..."
    # N = nullglob (no error if no matches), -. = regular files following symlinks
    # @ = symlinks only; skip files already symlinked into src_path
    for file in ~/.*history(N-.); do
      [[ -L ${file} && $(readlink "${file}") == "${src_path}"/* ]] && continue
      cp -Lf "${file}" "${src_path}/"
    done
    # ^ = negation (requires EXTENDED_GLOB), N = nullglob, . = regular files only
    for file in "${src_path}"/.^sync-conflict*(N.); do
      echo "> ${file}" && ln -sf "${file}" ~/
    done
  else
    printf "${RED}%s${NC}\n" "${src_path} not found. Please configure Syncthing and perform a sync run first."
  fi

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
