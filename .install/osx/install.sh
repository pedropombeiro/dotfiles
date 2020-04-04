#!/usr/bin/env bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Install software through Homebrew (https://formulae.brew.sh/)
brew update

brew install asciinema \
             autojump \
             coreutils \
             fzf \
             gnutls \
             htop \
             httpie \
             jq \
             mackup \
             mas-cli/tap/mas \
             mc \
             moreutils \
             ncdu \
             nvm \
             python \
             syncthing \
             the_silver_searcher \
             tig \
             watch \
             wget \
             xz \
             youtube-dl \
             yq
brew cask install balenaetcher \
                  beyond-compare \
                  docker \
                  dropbox \
                  fork \
                  google-chrome \
                  krisp \
                  libreoffice \
                  macpass \
                  microsoft-edge \
                  monitorcontrol \
                  plex \
                  protonmail-bridge \
                  protonvpn \
                  rescuetime \
                  skype \
                  spotify \
                  syncthing \
                  tripmode \
                  visual-studio-code

brew services start syncthing

APPLEID="$(mas account || echo '')"

if [ "$APPLEID" = "ppombeiro@gitlab.com" ]; then
  # For a GitLab development machine
  brew install minikube derailed/k9s/k9s
  brew cask install 1password google-cloud-sdk jetbrains-toolbox slack
fi

# Install nvm (https://github.com/nvm-sh/nvm#installing-and-updating)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash

# Install Oh-my-zsh
chmod o-w,g-w /usr/local/share/zsh /usr/local/share/zsh/site-functions
export KEEP_ZSHRC=yes
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

set +e
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

sudo wget -O "/Library/Fonts/MesloLGS NF Regular.ttf" https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf
sudo wget -O "/Library/Fonts/MesloLGS NF Bold.ttf" https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf
sudo wget -O "/Library/Fonts/MesloLGS NF Italic.ttf" https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf
sudo wget -O "/Library/Fonts/MesloLGS NF Bold Italic.ttf" https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf

source ${SCRIPT_DIR}/defaults.sh

# Install App Store apps
mas account > /dev/null || echo "Please log in to the App Store before proceeding. Press any key to continue" && read -k 1

mas install 918207447 # Annotate
mas install 973134470 # Be Focused
mas install 865500966 # Feedly
mas install 409183694 # Keynote
mas install 409203825 # Numbers
mas install 568494494 # Pocket
mas install 692867256 # Simplenote
mas install 957734279 # Toggl Desktop
mas install 485812721 # TweetDeck
mas install 1147396723 # WhatsApp

# Create SSH key for github.com and gitlab.com
# https://help.github.com/en/github/authenticating-to-github/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519.pub -C "noreply@pedro.pombei.ro"
pbcopy < ~/.ssh/id_ed25519.pub
echo "Add the SSH key from keyboard to your GitLab account. Opening browser..."
open https://gitlab.com/profile/keys
echo "Press Return when done"
read -r

echo "Add the SSH key from keyboard to your GitHub account. Opening browser..."
open https://github.com/settings/keys
echo "Press Return when done"
read -r
