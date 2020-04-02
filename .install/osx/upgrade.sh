#!/usr/bin/env bash

# Update App Store apps
sudo softwareupdate -i -a

# Update Homebrew (Cask) & packages
brew update
brew upgrade

# Update npm packages
npm update -g
