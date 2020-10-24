#!/usr/bin/env bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Enable TouchID on shell
grep 'pam_tid.so' /etc/pam.d/sudo > /dev/null || \
  echo -e "auth       sufficient     pam_tid.so\n$(cat /etc/pam.d/sudo)" | \
  sudo tee /etc/pam.d/sudo

# Install pre-requisites through Homebrew (https://formulae.brew.sh/)
brew update

brew install autojump \
             fzf \
             jq \
             mackup \
             mas \
             wget

echo "source ~/.bash_profile.shared" >> ~/.bash_profile
echo "source ~/.bashrc.shared" >> ~/.bashrc

if [ ! -d ~/.oh-my-zsh/ ]; then
  # Install Oh-my-zsh
  chmod o-w,g-w /usr/local/share/zsh /usr/local/share/zsh/site-functions
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
  echo "source ~/.zshrc.shared" > ~/.zshrc
fi

set +e
[ -d "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/themes/powerlevel10k" ] || git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/themes/powerlevel10k"
[ -d "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ] || git clone https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
[ -d "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" ] || git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
[ -d "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/you-should-use" ] || git clone https://github.com/MichaelAquilina/zsh-you-should-use.git "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/you-should-use"
set -e

# Install software through Homebrew (https://formulae.brew.sh/)
brew install aria2 \
             asciinema \
             asdf \
             bat \
             calc \
             coreutils \
             gnutls \
             htop \
             httpie \
             zaquestion/tap/lab \
             mc \
             moreutils \
             nano \
             ncdu \
             pinentry-mac \
             python \
             ripgrep \
             speedtest_cli \
             syncthing \
             switchaudio-osx \
             the_silver_searcher \
             tig \
             watch \
             xz \
             youtube-dl \
             yq

sudo ln -sf /usr/local/bin/pinentry-mac /usr/local/bin/pinentry-xp

brew tap homebrew/cask-drivers
brew tap homebrew/cask-fonts
brew cask install alfred \
                  appcleaner \
                  aria2d \
                  balenaetcher \
                  bartender \
                  beyond-compare \
                  boom-3d \
                  cakebrew \
                  cheatsheet \
                  dash \
                  dropbox \
                  elgato-control-center \
                  font-jetbrains-mono \
                  font-meslo-lg-nerd-font \
                  fork \
                  gimp \
                  google-chrome \
                  gpg-suite \
                  istat-menus \
                  iterm2 \
                  kap \
                  keepassxc \
                  krisp \
                  libreoffice \
                  logitech-camera-settings \
                  logitech-firmwareupdatetool \
                  logitech-options \
                  logitech-unifying \
                  lunar \
                  little-snitch \
                  micro-snitch \
                  microsoft-edge \
                  muzzle \
                  ngrok \
                  numi \
                  p4v \
                  plex \
                  protonmail-bridge \
                  protonvpn \
                  rescuetime \
                  skype \
                  spotify \
                  stay \
                  syncthing \
                  toggl-track \
                  tripmode \
                  visual-studio-code \
                  whatsapp

brew services start syncthing

sudo mdutil -i off /
sudo mdutil -E /

APPLEID="$(mas account || echo '')"

if [ "${APPLEID}" = "ppombeiro@gitlab.com" ]; then
  # For a GitLab development machine
  brew install docker-machine \
               docker-machine-parallels \
               dive \
               graphviz \
               minio/stable/minio \
               minikube \
               helm \
               derailed/k9s/k9s
  brew cask install 0xed \
                    1password \
                    docker \
                    google-cloud-sdk \
                    google-drive-file-stream \
                    jetbrains-toolbox \
                    slack \
                    vagrant \
                    zoomus

  brew services start docker-machine
fi

set +e
for p in golang golangci-lint hadolint nodejs yarn ruby shellcheck; do
  asdf plugin add "${p}"
done
asdf install golang 1.13.8 && asdf global golang 1.13.8
asdf install golangci-lint 1.27.0 && asdf global golangci-lint 1.27.0
asdf install hadolint v1.18.0 && asdf global hadolint v1.18.0
asdf install shellcheck 0.7.1 && asdf global shellcheck 0.7.1

bash -c '${ASDF_DATA_DIR:=$HOME/.asdf}/plugins/nodejs/bin/import-release-team-keyring'
asdf install nodejs 14.5.0 && asdf global nodejs 14.5.0
asdf install yarn 1.22.4 && asdf global yarn 1.22.4

asdf install ruby 2.6.6 && asdf global ruby 2.6.6
set -e

source "${SCRIPT_DIR}/defaults.sh"

# Complete installation of Little Snitch (will require restart)
open "$(find /usr/local/Caskroom/little-snitch -name 'LittleSnitch-*.dmg')"

# Install App Store apps
mas account > /dev/null || echo "Please log in to the App Store before proceeding. Press Enter to continue" && read -r

mas install 937984704  # Amphetamine
mas install 918207447  # Annotate
mas install 865500966  # Feedly
mas install 430798174  # HazeOver
mas install 409183694  # Keynote
mas install 409203825  # Numbers
mas install 568494494  # Pocket
mas install 692867256  # Simplenote
mas install 1176895641 # Spark
mas install 957734279  # Toggl Desktop
mas install 907364780  # Tomato One
mas install 485812721  # TweetDeck

mas install 1085114709 # Parallels Desktop

if ! [[ -f ~/.ssh/id_ed25519.pub ]]; then
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
fi
