#!/usr/bin/env bash

# Update Oh-my-zsh custom themes and plugins
find "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/themes" -type d -mindepth 1 -maxdepth 1 -exec git -C {} pull \;
find "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins" -type d -mindepth 1 -maxdepth 1 -exec git -C {} pull \;

# Update App Store apps
sudo softwareupdate -i -a

# Update Homebrew (Cask) & packages
brew update
brew upgrade
brew cask upgrade

# Update npm packages
npm update -g
