#!/usr/bin/env zsh

# Update Oh-my-zsh custom themes and plugins
DISABLE_AUTO_UPDATE=true source "${HOME}/.oh-my-zsh/oh-my-zsh.sh"
omz update
find "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/themes" -mindepth 1 -maxdepth 1 -type d -exec git -C {} pull \;
find "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins" -mindepth 1 -maxdepth 1 -type d -exec git -C {} pull \;

# Update App Store apps
sudo softwareupdate -i -a

source "${HOME}/.config/yadm/scripts/enable-touchid-on-terminal.sh"
source "${HOME}/.config/yadm/scripts/relink-dotfiles.sh"

# Update Homebrew (Cask) & packages
brew update
brew upgrade

# Update npm packages
command -v npm >/dev/null && npm update -g

# Fix GPG agent symlink if broken
ln -sf /usr/local/MacGPG2/bin/gpg-agent /usr/local/bin/gpg-agent
