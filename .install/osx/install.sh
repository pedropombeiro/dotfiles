#!/usr/bin/env bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Install pre-requisites through Homebrew (https://formulae.brew.sh/)
brew update

brew install autojump \
             fzf \
             jq \
             mackup \
             mas-cli/tap/mas \
             wget

echo "source ~/.bash_profile.shared" >> ~/.bash_profile
echo "source ~/.bashrc.shared" >> ~/.bashrc

# Install Oh-my-zsh
chmod o-w,g-w /usr/local/share/zsh /usr/local/share/zsh/site-functions
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
echo "source ~/.zshrc.shared" > ~/.zshrc

set +e
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

sudo wget -O "/Library/Fonts/MesloLGS NF Regular.ttf" https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf
sudo wget -O "/Library/Fonts/MesloLGS NF Bold.ttf" https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf
sudo wget -O "/Library/Fonts/MesloLGS NF Italic.ttf" https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf
sudo wget -O "/Library/Fonts/MesloLGS NF Bold Italic.ttf" https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf
set -e

# Install software through Homebrew (https://formulae.brew.sh/)
brew install asciinema \
             coreutils \
             gnutls \
             htop \
             httpie \
             mc \
             moreutils \
             nano \
             ncdu \
             nvm \
             python \
             shellcheck \
             syncthing \
             the_silver_searcher \
             tig \
             watch \
             xz \
             youtube-dl \
             yq
brew cask install balenaetcher \
                  beyond-compare \
                  cheatsheet \
                  dash \
                  dropbox \
                  homebrew/cask-drivers/elgato-control-center \
                  fork \
                  gimp \
                  google-chrome \
                  gpg-suite \
                  iterm2 \
                  itsycal \
                  krisp \
                  libreoffice \
                  little-snitch \
                  macpass \
                  microsoft-edge \
                  monitorcontrol \
                  muzzle \
                  numi \
                  p4v \
                  plex \
                  protonmail-bridge \
                  protonvpn \
                  recordit \
                  rescuetime \
                  skype \
                  spotify \
                  syncthing \
                  toggl \
                  tripmode \
                  visual-studio-code \
                  whatsapp

brew services start syncthing

APPLEID="$(mas account || echo '')"

if [ "${APPLEID}" = "ppombeiro@gitlab.com" ]; then
  # For a GitLab development machine
  brew install docker-machine \
               minikube \
               derailed/k9s/k9s
  brew cask install 1password \
                    docker \
                    google-cloud-sdk \
                    google-drive-file-stream \
                    jetbrains-toolbox \
                    slack \
                    zoomus

  brew services start docker-machine

  # Install Go Version Manager
  GVM_NO_UPDATE_PROFILE=1 bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
  echo "source ~/.gvm/scripts/gvm" >> ~/.zshrc
fi

# Install nvm (https://github.com/nvm-sh/nvm#installing-and-updating)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash

source "${SCRIPT_DIR}/defaults.sh"

# Complete installation of Little Snitch (will require restart)
open "$(find /usr/local/Caskroom/little-snitch -name 'LittleSnitch-*.dmg')"

# Install App Store apps
mas account > /dev/null || echo "Please log in to the App Store before proceeding. Press Enter to continue" && read -r

mas install 937984704 # Amphetamine
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
