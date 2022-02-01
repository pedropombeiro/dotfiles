#!/usr/bin/env bash

source "${HOME}/.install/colors.sh"

printf "${YELLOW}%s${NC}" "Updating tldr..."
tldr --update

# Update Oh-my-zsh custom themes and plugins
DISABLE_AUTO_UPDATE=true source "${HOME}/.oh-my-zsh/oh-my-zsh.sh"
omz update
find "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/themes" -mindepth 1 -maxdepth 1 -type d -print0 | xargs -0 -P 8 -I {} git -C {} pull --prune --stat -v --ff-only
find "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins" -mindepth 1 -maxdepth 1 -type d -print0 | xargs -0 -P 8 -I {} git -C {} pull --prune --stat -v --ff-only

printf "${YELLOW}%s${NC}\n" "Updating vim plugins..."
find "${HOME}/.vim/pack" -type d -name .git -print0 | xargs -0 -P 8 -I {} git -C {}/.. pull --prune --stat -v --ff-only && printf "${GREEN}%s${NC}\n" "Done"
