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

"${YADM_SCRIPTS}/migrate-legacy-dirs.zsh"

printf "${YELLOW}%s${NC}\n" "Linking run-in-tmux-pane..."
mkdir -p "${HOME}/.local/bin"
ln -sfn "${HOME}/.agents/skills/run-in-tmux-pane/scripts/run-in-tmux-pane" "${HOME}/.local/bin/run-in-tmux-pane"

gopro_graphics="${HOME}/Developer/github.com/pedropombeiro/gopro-graphics"
if [[ -d ${gopro_graphics}/bin ]]; then
  printf "${YELLOW}%s${NC}\n" "Linking gopro-graphics scripts..."
  for script in "${gopro_graphics}"/bin/*(N-.x); do
    ln -sfn "${script}" "${HOME}/.local/bin/${script:t}"
  done
  unset script
fi
unset gopro_graphics

class="$(yadm config local.class)"

"${YADM_SCRIPTS}/link-private-work-files.zsh"

if [[ ${class} == 'Personal' || ${class} == 'Work' ]]; then
  src_path="${HOME}/Sync/pedro/.dotfiles/Home/MBP.${class}"
  if [[ -d ${src_path} ]]; then
    printf "${YELLOW}%s${NC}\n" "Linking .dotfiles in ${src_path} to ${HOME}..."
    # N = nullglob (no error if no matches), -. = regular files following symlinks
    # Keep restored histories authoritative, preserving differing local copies
    # outside src_path so the linking loop below won't pick up the backups.
    history_backup_dir=""
    for file in ~/.*history(N-.); do
      [[ -L ${file} && $(readlink "${file}") == "${src_path}"/* ]] && continue
      if [[ -e ${src_path}/${file:t} || -L ${src_path}/${file:t} ]]; then
        if ! cmp -s "${file}" "${src_path}/${file:t}"; then
          if [[ -z ${history_backup_dir} ]]; then
            history_backup_root="${XDG_STATE_HOME:-${HOME}/.local/state}/yadm/history-backups"
            (umask 077; mkdir -p "${history_backup_root}") || exit 1
            history_backup_dir=$(mktemp -d "${history_backup_root}/restore.XXXXXX") || exit 1
          fi
          cp -pL "${file}" "${history_backup_dir}/" || exit 1
          printf "${YELLOW}%s${NC}\n" "Saved local history to ${history_backup_dir}/${file:t}"
        fi
      else
        cp -pL "${file}" "${src_path}/" || exit 1
      fi
    done
    unset history_backup_dir history_backup_root
    # ^ = negation (requires EXTENDED_GLOB), N = nullglob, . = regular files only
    for file in "${src_path}"/.^sync-conflict*(N.); do
      echo "> ${file}" && ln -sf "${file}" ~/
    done
  elif [[ ${class} == 'Work' ]]; then
    # Syncthing isn't allowed on Work machines.
    printf "${RED}%s${NC}\n" "${src_path} not found. Copy it from the previous Work machine."
  else
    printf "${RED}%s${NC}\n" "${src_path} not found. Please configure Syncthing and perform a sync run first."
  fi

  # Only once the synced folder exists: seeding it would create a partial
  # MBP.<class> tree that looks restored and conflicts with the real copy.
  if [[ -d ${src_path} && -d ${HOME}/.config/pgcli ]]; then
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
