#!/usr/bin/env bash

# Install software
brew install asciinema \
             autojump \
             coreutils \
             fzf \
             gnutls \
             htop \
             httpie \
             jq \
             mas-cli/tap/mas \
             moreutils \
             ncdu \
             nvm \
             python@3.8 \
             the_silver_searcher \
             tig \
             watch \
             wget \
             xz \
             youtube-dl \
             yq \
brew cask install 1password \
                  balenaetcher \
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
                  slack \
                  spotify \
                  syncthing \
                  tripmode \
                  virtualbox \
                  visual-studio-code

brew services start syncthing

# For a GitLab development machine
brew install minikube derailed/k9s/k9s
brew cask install google-cloud-sdk

# Install App Store apps
if [ -z "$(mas account)" ]; then
  read -p "Please enter your Apple ID:" APPLEID

  mas signin "${APPLEID}"
fi
mas install 994933038 # Annotate
mas install 973130201 # Be Focused
mas install 865500966 # Feedly
mas install 409183694 # Keynote
mas install 409203825 # Numbers
mas install 568494494 # Pocket
mas install 692867256 # Simplenote
mas install 957734279 # Toggl Desktop
mas install 485812721 # TweetDeck
mas install 1147396723 # WhatsApp

source ${BASH_SOURCE}/defaults.sh
