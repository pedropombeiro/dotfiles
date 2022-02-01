#!/usr/bin/env zsh

source "${HOME}/.config/yadm/scripts/enable-touchid-on-terminal.sh"
source "${HOME}/.config/yadm/scripts/relink-dotfiles.sh"

# Update Homebrew (Cask) & packages
brew update
brew upgrade

source "${HOME}/.install/update-common.sh"

asdf plugin-update --all
echo 'fzf\ngolangci-lint\nshellcheck' | xargs -I {} bash -c 'asdf install {} latest && asdf global {} latest'

# Update npm packages
command -v npm >/dev/null && npm update -g

# Fix GPG agent symlink if broken
ln -sf /usr/local/MacGPG2/bin/gpg-agent /usr/local/bin/gpg-agent
