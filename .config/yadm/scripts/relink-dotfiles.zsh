#!/usr/bin/env zsh

setopt LOCAL_OPTIONS EXTENDED_GLOB

# ${(%):-%x} = zsh equivalent of bash's ${BASH_SOURCE[0]}
YADM_SCRIPTS=$(cd -- "$(dirname -- "${(%):-%x}")/../scripts" &>/dev/null && pwd)

source "${YADM_SCRIPTS}/colors.sh"

"${YADM_SCRIPTS}/sync-work-skills.zsh" || exit $?

pinchtab_skill="${HOME}/Developer/github.com/pinchtab/pinchtab/skills/pinchtab"
if [[ -d ${pinchtab_skill} ]]; then
  printf "${YELLOW}%s${NC}\n" "Linking PinchTab skill..."
  ln -sfn "${pinchtab_skill}" "${HOME}/.agents/skills/pinchtab"
  if [[ ! -L ${HOME}/.claude/skills/pinchtab ]]; then
    rm -rf "${HOME}/.claude/skills/pinchtab"
  fi
  ln -sfn "${HOME}/.agents/skills/pinchtab" "${HOME}/.claude/skills/pinchtab"
fi

printf "${YELLOW}%s${NC}\n" "Linking OpenCode skills..."
if [[ -L ${HOME}/.config/opencode/skills/skills &&
      $(readlink "${HOME}/.config/opencode/skills/skills") == "${HOME}/.agents/skills" ]]; then
  rm "${HOME}/.config/opencode/skills/skills"
  rmdir "${HOME}/.config/opencode/skills"
fi
ln -sfn "${HOME}/.agents/skills" "${HOME}/.config/opencode/skills"

# yadm only prunes links whose target still has tracked alternates, so links to
# the removed tui.json and cli.json alternates would dangle forever. cli.json is
# now a regular file that OpenCode owns; only remove it while it is a symlink.
for opencode_orphan in tui.json cli.json; do
  if [[ -L ${HOME}/.config/opencode/${opencode_orphan} ]]; then
    rm -f "${HOME}/.config/opencode/${opencode_orphan}"
  fi
done
unset opencode_orphan

printf "${YELLOW}%s${NC}\n" "Linking run-in-tmux-pane..."
mkdir -p "${HOME}/.local/bin"
ln -sfn "${HOME}/.agents/skills/run-in-tmux-pane/scripts/run-in-tmux-pane" "${HOME}/.local/bin/run-in-tmux-pane"

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
