#!/usr/bin/env bash

# Update App Store apps
sudo apt update
sudo apt upgrade

# Update Oh-my-zsh custom themes and plugins
git -C ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k pull
git -C ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions pull
git -C ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting pull

# Update npm packages
npm update -g
