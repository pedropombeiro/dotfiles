#!/usr/bin/env zsh

# Update Oh-my-zsh custom themes and plugins
DISABLE_AUTO_UPDATE=true source "${HOME}/.oh-my-zsh/oh-my-zsh.sh"
omz update
find "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/themes" -mindepth 1 -maxdepth 1 -type d -exec git -C {} pull \;
find "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins" -mindepth 1 -maxdepth 1 -type d -exec git -C {} pull \;

# Update App Store apps
sudo softwareupdate -i -a

# Update Homebrew (Cask) & packages
brew update
brew upgrade

# Update npm packages
npm update -g

# Enable TouchID on shell
grep 'pam_tid.so' /etc/pam.d/sudo > /dev/null || \
  echo -e "auth       sufficient     pam_tid.so\n$(cat /etc/pam.d/sudo)" | \
  sudo tee /etc/pam.d/sudo
