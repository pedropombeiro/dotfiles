#!/usr/bin/env zsh

# Update apps
sudo apt update
sudo apt upgrade

# Update Homebrew apps
brew update
brew upgrade

# Update Oh-my-zsh custom themes and plugins
DISABLE_AUTO_UPDATE=true source "${HOME}/.oh-my-zsh/oh-my-zsh.sh"
omz update
find "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/themes" -mindepth 1 -maxdepth 1 -type d -exec git -C {} pull \;
find "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins" -mindepth 1 -maxdepth 1 -type d -exec git -C {} pull \;

# Update npm packages
command -v npm 2>/dev/null && npm update -g
