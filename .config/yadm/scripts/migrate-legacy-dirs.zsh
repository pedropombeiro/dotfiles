#!/usr/bin/env zsh
#
# Move tool state from legacy $HOME directories to the XDG locations that the
# tracked config now points at. relink-dotfiles.zsh runs this after every yadm
# checkout, so each machine migrates the first time it pulls the change.

setopt EXTENDED_GLOB

source "${0:A:h}/colors.sh"

config_home=${XDG_CONFIG_HOME:-${HOME}/.config}
cache_home=${XDG_CACHE_HOME:-${HOME}/.cache}
data_home=${XDG_DATA_HOME:-${HOME}/.local/share}
state_home=${XDG_STATE_HOME:-${HOME}/.local/state}

# Move the entries of $1 into $2 without overwriting anything, recursing into
# directories that exist on both sides. Removes $1 once it is empty.
merge_into_dir() {
  local src=$1 dst=$2 entry
  mkdir -p "${dst}" || return 1
  # D = include dotfiles, N = nullglob
  for entry in "${src}"/*(DN); do
    if [[ ! -e ${dst}/${entry:t} && ! -L ${dst}/${entry:t} ]]; then
      mv "${entry}" "${dst}/" || return 1
    elif [[ -d ${entry} && ! -L ${entry} && -d ${dst}/${entry:t} ]]; then
      merge_into_dir "${entry}" "${dst}/${entry:t}" || return 1
    fi
  done
  rmdir "${src}" 2>/dev/null
  return 0
}

# Merge legacy directory $1 into $2. Entries that already exist in $2 are kept
# under ${state_home}/yadm/legacy-conflicts, unless $3 is "cache", in which
# case they are deleted. Returns 0 only when $1 existed.
migrate_dir() {
  local src=$1 dst=$2 kind=${3:-} backup
  [[ -d ${src} && ! -L ${src} ]] || return 1
  printf "${YELLOW}%s${NC}\n" "Migrating ${src/#${HOME}/~} to ${dst/#${HOME}/~}..."
  merge_into_dir "${src}" "${dst}" || return 1
  if [[ -d ${src} && ${kind} == cache ]]; then
    # Processes started before the move can recreate a cache in the old place.
    rm -rf "${src}"
  elif [[ -d ${src} ]]; then
    # ~/.bundle/cache -> .bundle_cache
    backup="${state_home}/yadm/legacy-conflicts/${${src#${HOME}/}//\//_}.$(date +%Y%m%d%H%M%S)"
    mkdir -p "${backup:h}" && mv "${src}" "${backup}" &&
      printf "${YELLOW}%s${NC}\n" "Kept conflicting entries in ${backup/#${HOME}/~}"
  fi
  return 0
}

# lnav reads ~/.config/lnav only while ~/.lnav doesn't exist.
migrate_dir "${HOME}/.lnav" "${config_home}/lnav"

# yadm leaves the emptied directories behind, and highlight --list-scripts
# aborts on an empty ~/.highlight/themes.
rmdir "${HOME}/.highlight/themes" "${HOME}/.highlight" 2>/dev/null

migrate_dir "${HOME}/.dlv" "${config_home}/dlv"
migrate_dir "${HOME}/.npm" "${cache_home}/npm" cache

migrate_dir "${HOME}/.bundle/cache" "${cache_home}/bundler" cache
rmdir "${HOME}/.bundle" 2>/dev/null

migrate_dir "${HOME}/.atuin/logs" "${state_home}/atuin/logs"
rmdir "${HOME}/.atuin" 2>/dev/null

if migrate_dir "${HOME}/.tmux/plugins" "${data_home}/tmux/plugins"; then
  rmdir "${HOME}/.tmux" 2>/dev/null
  # A running server still has the old plugin paths in its status line.
  # Re-sourcing the config points TPM and the plugins at the new location.
  if tmux info &>/dev/null; then
    tmux source-file "${config_home}/tmux/tmux.conf"
  fi
fi

exit 0
