#!/usr/bin/env zsh
#
# Link internal Work files that must not be in the public repo. They live under
# home/ in the private gitlab-dotfiles checkout, at their path relative to
# $HOME. Runs from relink-dotfiles.zsh and from update-work.zsh after the
# checkout is refreshed, so files added upstream are linked in the same update.

YADM_SCRIPTS=$( cd -- "$( dirname -- ${(%):-%x} )" &>/dev/null && pwd )

source "${YADM_SCRIPTS}/colors.sh"

[[ $(yadm config local.class) == Work ]] || exit 0

private_home="${HOME}/.config/dotfiles/gitlab/home"
[[ -d ${private_home} ]] || exit 0

printf "${YELLOW}%s${NC}\n" "Linking private Work files from ${private_home}..."
# N = nullglob, D = include dotfiles, . = regular files only
for file in "${private_home}"/**/*(ND.); do
  target="${HOME}/${file#${private_home}/}"
  mkdir -p "${target:h}"
  ln -sfn "${file}" "${target}"
done
