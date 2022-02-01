#!/usr/bin/env zsh

source "${HOME}/.install/colors.sh"

source "${HOME}/.config/yadm/scripts/enable-touchid-on-terminal.sh"
source "${HOME}/.config/yadm/scripts/relink-dotfiles.sh"

# Update Homebrew (Cask) & packages
printf "${YELLOW}%s${NC}\n" "Updating brew..."
brew update
brew upgrade

source "${HOME}/.install/update-common.sh"

printf "${YELLOW}%s${NC}\n" "Updating asdf..."
asdf plugin-update --all
echo 'fzf\ngolangci-lint\nshellcheck' | xargs -I {} bash -c 'asdf install {} latest && asdf global {} latest'

# Update npm packages
printf "${YELLOW}%s${NC}\n" "Updating npm global packages..."
command -v npm >/dev/null && npm update -g

# Fix GPG agent symlink if broken
ln -sf /usr/local/MacGPG2/bin/gpg-agent /usr/local/bin/gpg-agent
