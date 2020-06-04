#!/usr/bin/env bash

# Update App Store apps
sudo softwareupdate -i -a

# Update Homebrew (Cask) & packages
brew update
brew upgrade
brew cask upgrade

# Update Oh-my-zsh custom themes and plugins
git -C "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k" pull
git -C "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" pull
git -C "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" pull

# Update npm packages
npm update -g
