#!/usr/bin/env bash

rm -f ~/Downloads/*

# Adapt Firefox settings
def_Pfile=`cat "$HOME/.mozilla/firefox/profiles.ini" | sed -n -e 's/^.*Path=//p' | head -n 1`
# Enable FIDO U2F in Firefox
echo "user_pref(\"security.webauth.u2f\", \"true\");" >> $HOME/.mozilla/firefox/$def_Pfile/prefs.js

sudo apt update

# Fix a bug in Ubuntu 18.04 making the DNS server provided by DHCP be ignored (https://askubuntu.com/a/1041631/780635)
sudo rm -f /etc/resolv.conf
sudo ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf

#sudo timedatectl set-local-rtc 1 # needed when dual-booting with Windows
sudo timedatectl set-ntp no && \
  timedatectl && \
  sudo apt install -y ntp
# TODO: Add "server ntp.pedropombeiro.com" to /etc/ntp.conf

sudo apt install -y preload gnome-tweak-tool unity-tweak-tool build-essential \
  gdebi-core httpie network-manager-openvpn-gnome mc moreutils tig \
  rng-tools asciinema

# Oh-my-zsh
sudo apt install -y zsh
zsh --version
chsh -s $(which zsh)
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

git clone https://github.com/bhilburn/powerlevel9k.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel9k
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# https://github.com/robbyrussell/oh-my-zsh/wiki/Plugins#git
# Fonts for powerlevel theme in VS Code: https://dev.to/mattstratton/making-powerline-work-in-visual-studio-code-terminal-1m7
sudo apt install -y zsh fonts-powerline
sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
git clone https://github.com/bhilburn/powerlevel9k.git ~/.oh-my-zsh/custom/themes/powerlevel9k

sudo apt install -y ccze # https://blog.tersmitten.nl/how-to-colorize-your-log-files-with-ccze.html

download_dir=/home/$LOGNAME/Downloads

# s-tui (https://github.com/amanusk/s-tui)
sudo add-apt-repository ppa:amanusk/python-s-tui
sudo apt-get update
sudo apt-get install python3-s-tui

gsettings set com.ubuntu.user-interface scale-factor "{'': 8, 'DP-1': 16, 'eDP-1': 16}"

# autorandr
sudo apt install -y autorandr
cat << EOF > /lib/udev/40-monitor-hotplug.rules
ACTION=="change", SUBSYSTEM=="drm", RUN+="/usr/bin/autorandr --batch --change --default default"
EOF

# brightness-controller
sudo add-apt-repository ppa:apandada1/brightness-controller && \
  sudo apt install -y brightness-controller

# ProtonMail Bridge
cd $download_dir && \
  wget -O protonmail-bridge.deb https://protonmail.com/download/protonmail-bridge_1.2.6-1_amd64.deb
  sudo gdebi protonmail-bridge.deb

# ProtonVPN
sudo apt install -y openvpn dialog python3-pip python3-setuptools
sudo pip3 install protonvpn-cli

# Simplenote
cd $download_dir && \
  wget -O simplenote.deb https://github.com/Automattic/simplenote-electron/releases/download/v1.1.6/simplenote_1.1.6_amd64.deb
  sudo gdebi simplenote.deb

# Ledger Nano S
wget -q -O - https://raw.githubusercontent.com/LedgerHQ/udev-rules/master/add_udev_rules.sh | sudo bash
sudo apt install -y python3-pip libusb-1.0-0-dev libudev-dev
sudo pip3 install btchip-python

cd $download_dir && wget -O ledger-live-desktop-linux-x86_64.AppImage https://github.com/LedgerHQ/ledger-live-desktop/releases/download/v1.0.1/ledger-live-desktop-1.0.1-linux-x86_64.AppImage && \
  chmod +x ledger-live-desktop-linux-x86_64.AppImage && \
  sudo mv ledger-live-desktop-linux-x86_64.AppImage /usr/local/bin/

# Google Chrome
echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list && \
  cd $download_dir && wget https://dl.google.com/linux/linux_signing_key.pub && \
  sudo apt-key add linux_signing_key.pub && \
  sudo apt update && \
  sudo apt install google-chrome-stable

# RescueTime
cd $download_dir && wget https://www.rescuetime.com/installers/rescuetime_current_amd64.deb && \
  sudo gdebi rescuetime_current_amd64.deb

# Toggl
cd $download_dir && \
  wget http://fr.archive.ubuntu.com/ubuntu/pool/main/g/gst-plugins-base0.10/libgstreamer-plugins-base0.10-0_0.10.36-1_amd64.deb && \
  wget http://fr.archive.ubuntu.com/ubuntu/pool/universe/g/gstreamer0.10/libgstreamer0.10-0_0.10.36-1.5ubuntu1_amd64.deb && \
  sudo gdebi libgstreamer*.deb && \
  wget --max-redirect=3 -O toggl.deb "https://toggl.com/api/v8/installer?app=td&platform=deb64&channel=stable" && \
  sudo gdebi toggl.deb && \
  sudo mv /usr/share/applications/toggldesktop.desktop /usr/share/applications/toggldesktop.desktop.orig && \
  sudo bash -c "sed -e 's/Exec=\/opt\/toggldesktop\/TogglDesktop.sh/Exec=env QT_DEVICE_PIXEL_RATIO=2 \/opt\/toggldesktop\/TogglDesktop.sh/' /usr/share/applications/toggldesktop.desktop.orig > /usr/share/applications/toggldesktop.desktop"

# Skype
#cd $download_dir && wget https://repo.skype.com/latest/skypeforlinux-64.deb && \
#  sudo gdebi skypeforlinux-64.deb

# Pushbullet
cd $download_dir && wget -O pb-for-desktop.deb https://github.com/sidneys/pb-for-desktop/releases/download/v6.7.7/pb-for-desktop-6.7.7-amd64.deb && \
  sudo gdebi pb-for-desktop.deb

sudo apt --fix-broken install -y

# Docker CE
sudo apt update && \
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - &&
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   edge" && \
   sudo apt update && \
   sudo apt install -y docker-ce && \
   sudo docker run hello-world && \
   sudo usermod -a -G docker $LOGNAME

# Docker Compose
sudo curl -L https://github.com/docker/compose/releases/download/1.21.2/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose && \
  sudo chmod +x /usr/local/bin/docker-compose

# Beyond Compare 4
cd $download_dir && wget -O bcompare_amd64.deb https://www.scootersoftware.com/bcompare-4.3.4.24657_amd64.deb && \
  sudo gdebi bcompare_amd64.deb && \
  sudo ln -sf /usr/bin/bcompare /usr/local/bin/bcompare # For compatibility with install on MacOS

# P4Merge
cd $download_dir && wget https://www.perforce.com/downloads/perforce/r17.3/bin.linux26x86_64/p4v.tgz && \
  tar zxvf p4v.tgz && \
  sudo cp -r p4v-* /usr/local/p4v/ && \
  sudo ln -s /usr/local/p4v/bin/p4merge /usr/bin/p4merge

# VS Code
cd $download_dir && curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg && \
  sudo mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg && \
  sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list' && \
  sudo apt update && \
  sudo apt install -y code && \
  sudo apt install -y xclip # adds support for copying to the clipboard

# Yubikey
sudo add-apt-repository -y ppa:yubico/stable &&  \
  sudo apt update && \
  sudo apt install -y pinentry-curses scdaemon pcscd yubikey-personalization libusb-1.0-0-dev && \
  sudo apt install -y yubikey-neo-manager

## TODO: Follow https://github.com/drduh/YubiKey-Guide#install---linux
echo 'hkp-cacert /etc/sks-keyservers.netCA.pem' >> ~/.gnupg/dirmngr.conf

# GPG
sudo apt install -y gnupg2 gnupg-agent
gpg2 --recv 0x91527A684B864DC0 # Install Yubikey public key
gpg2 --list-secret-keys --keyid-format LONG
echo 'export GPG_TTY=$(tty)' >> ~/.profile

# Git
sudo add-apt-repository -y ppa:git-core/ppa && \
  sudo apt update && \
  sudo apt install -y git

git config --global user.name 'Pedro Pombeiro'
git config --global user.email noreply@pedro.pombei.ro
git config --global user.signingkey B04C63F91EF312EF
git config --global commit.gpgsign true
git config --global push.default simple
git config --global gpg.program $(whereis -b gpg2 | cut -d ' ' -f2)

git config --global rebase.autoSquash true
git config --global rebase.autoStash true
git config --global rebase.missingCommitsCheck warn

git config --global diff.tool beyondcompare4
git config --global diff.guitool beyondcompare4
git config --global difftool.prompt false
git config --global difftool.beyondcompare4.cmd 'bcompare "$LOCAL" "$REMOTE"'
git config --global difftool.beyondcompare4.path /usr/bin/bcompare
git config --global difftool.beyondcompare4.keepTemporaries false
git config --global difftool.beyondcompare4.keepBackup false
git config --global difftool.beyondcompare4.trustExitCode true

git config --global merge.keepBackup false
git config --global merge.tool p4merge
git config --global merge.guitool p4merge
git config --global mergetool.prompt false
git config --global mergetool.p4merge.cmd 'p4merge "$BASE" "$LOCAL" "$REMOTE" "$MERGED"'
git config --global mergetool.p4merge.keepTemporaries false
git config --global mergetool.p4merge.keepBackup false
git config --global mergetool.p4merge.trustExitCode false

# GitExtensions
sudo apt install -y mono-complete
cd $download_dir && wget -O GitExtensions-Mono.zip https://github.com/gitextensions/gitextensions/releases/download/v2.51.05/GitExtensions-2.51.05-Mono.zip && \
  sudo unzip GitExtensions-Mono.zip -d /usr/local/bin/ &&
  sudo chmod +x /usr/local/bin/GitExtensions/gitext.sh
## GitExtensions should be run from the command line with `gitext.sh &`

cat << EOF > ~/GitExtensions.desktop
[Desktop Entry]
Type=Application
Terminal=false
Name=GitExtensions
Icon=/usr/local/bin/GitExtensions/git-extensions-logo-final-256.ico
Exec=/usr/local/bin/GitExtensions/gitext.sh
EOF
sudo mkdir -p /usr/local/share/applications
sudo mv ~/GitExtensions.desktop /usr/local/share/applications/GitExtensions.desktop

# Slack
sudo apt install -y slack

# KeePass
sudo apt-add-repository ppa:jtaylor/keepass && \
  sudo add-apt-repository ppa:dlech/keepass2-plugins && \
  sudo apt update && \
  sudo apt install -y keepass2 keepass2-plugin-keeagent xdotool && \
  sudo apt upgrade -y

cd $download_dir && wget -O KeeOtp.zip https://bitbucket.org/devinmartin/keeotp/downloads/KeeOtp-1.3.9.zip && \
  sudo mkdir -p /usr/lib/keepass2/plugins && \
  sudo unzip KeeOtp.zip -d /usr/lib/keepass2/plugins

# Android Studio
cd $download_dir && wget -O android-studio-ide-linux.zip https://dl.google.com/dl/android/studio/ide-zips/3.1.2.0/android-studio-ide-173.4720617-linux.zip && \
  sudo unzip android-studio-ide-linux.zip -d /usr/local/
  cd /usr/local/android-studio/bin/ && \
  ./studio.sh
sudo apt install -y libc6:i386 libncurses5:i386 libstdc++6:i386 lib32z1 libbz2-1.0:i386
## Update SDK
android update sdk --no-ui --use-sdk-wrapper

# KVM
sudo apt install -y qemu-kvm libvirt-bin ubuntu-vm-builder bridge-utils

# https://confluence.jetbrains.com/display/IDEADEV/Inotify+Watches+Limit
echo fs.inotify.max_user_watches = 524288 | sudo tee -a /etc/sysctl.conf

echo vm.swappiness=10 | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# ngrok
cd $download_dir && wget https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.zip && \
  sudo mkdir -p /usr/local/bin/ngrok &&
  sudo unzip ngrok-stable-linux-amd64.zip -d /usr/local/bin/ngrok/

echo PATH='/usr/local/go/bin:$HOME/go/bin:$PATH:/usr/local/bin/GitExtensions/:/usr/local/bin/ngrok/' | tee -a ~/.profile
echo export GOPATH=~/go | tee -a ~/.profile
echo export STATUS_GO_HOME=~/go/src/github.com/status-im/status-go | tee -a ~/.profile
echo export STATUS_REACT_HOME=~/src/github.com/status-im/status-react | tee -a ~/.profile

echo export REACT_EDITOR=code | tee -a ~/.bashrc

source ~/.profile

# Setup udev for Nexus 6P
sudo usermod -aG plugdev $LOGNAME # https://developer.android.com/studio/run/device.html && \
  sudo sh -c "echo '# Google Nexus 6P' >> /etc/udev/rules.d/51-android.rules" && \
  sudo sh -c "echo 'SUBSYSTEM==\"usb\", ATTR{idVendor}==\"18d1\", MODE=\"0664\", GROUP=\"plugdev\"' >> /etc/udev/rules.d/51-android.rules" && \
  sudo service udev restart

sudo apt install -y jq

# Plexamp
cd $download_dir && wget -O plexamp-x86_64.AppImage https://plexamp.plex.tv/plexamp.plex.tv/plexamp-1.0.5-x86_64.AppImage && \
  chmod +x plexamp-x86_64.AppImage && \
  sudo mv plexamp-x86_64.AppImage /usr/local/bin/

sudo apt install -f -y
sudo apt autoremove

# TODO: Open the dialog Keyboard Shortcuts in the system preferences, click the Add button, enter KeePass Auto-Type as name and
# mono /usr/lib/keepass2/KeePass.exe --auto-type
# as command, then click [Apply]. Click on Disabled of the newly created item (such that the text 'New shortcut...' appears), press Ctrl+Alt+A, and close the dialog.

sudo apt install -y cifs-utils # https://wiki.ubuntu.com/MountWindowsSharesPermanently
sudo sh -c "echo '//nas/home  /media/pedro  cifs  credentials=/home/pedro/.smbcredentials,iocharset=utf8,sec=ntlmv2  0  0' << /etc/fstab"

#sudo apt install -y smbclient
# # TODO: smbclient //nas/Download -U pedro%<password>
# TODO: http://ubuntuhandbook.org/index.php/2016/04/enable-ssh-ubuntu-16-04-lts/

gsettings set org.compiz.unityshell:/org/compiz/profiles/unity/plugins/unityshell/ launcher-minimize-window true
gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll false
gsettings set org.gnome.desktop.peripherals.touchpad click-method 'areas'

#wget https://www.privateinternetaccess.com/installer/pia-nm.sh && \
#  sudo bash pia-nm.sh

sudo mv /var/lib/snapd/desktop/applications/spotify_spotify.desktop /var/lib/snapd/desktop/applications/spotify_spotify.desktop.orig && \
  sudo bash -c "sed -e 's/Exec=env BAMF_DESKTOP_FILE_HINT=\/var\/lib\/snapd\/desktop\/applications\/spotify_spotify.desktop \/snap\/bin\/spotify %U/Exec=env BAMF_DESKTOP_FILE_HINT=\/var\/lib\/snapd\/desktop\/applications\/spotify_spotify.desktop \/snap\/bin\/spotify --force-device-scale-factor=1.5 %U/' /var/lib/snapd/desktop/applications/spotify_spotify.desktop.orig > /var/lib/snapd/desktop/applications/spotify_spotify.desktop"

# TODO: https://www.bettertechtips.com/linux/track-activities-linux/
rescuetime & disown
/usr/local/bin/ledger-live-desktop-linux-x86_64.AppImage & disown

###
### Lenovo ThinkPad-specific settings
###

# Decrease zoom factor in Firefox
echo "user_pref(\"layout.css.devPixelsPerPx\", \"1.75\");" >> $HOME/.mozilla/firefox/$def_Pfile/prefs.js

# Fix UI dimensions
gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 32

git clone git@github.com:PombeirP/autorandr-config.git ~/.autorandr

# https://wiki.archlinux.org/index.php/TLP
sudo apt install -y tlp acpi-call smartmontools
sudo systemctl start tlp.service
sudo systemctl start tlp-sleep.service
sudo systemctl mask systemd-rfkill.service
sudo systemctl mask systemd-rfkill.socket

# Fix CPU throttling (https://wiki.archlinux.org/index.php/Lenovo_ThinkPad_X1_Carbon_(Gen_6))
sudo apt install git virtualenv build-essential python3-dev \
  libdbus-glib-1-dev libgirepository1.0-dev libcairo2-dev && \
  cd ~/ && \
  git clone https://github.com/erpalma/lenovo-throttling-fix.git && \
  cd lenovo-throttling-fix/ && \
  sudo ./install.sh

# Allow PowerTop to auto tune at startup
cat << EOF | sudo tee /etc/systemd/system/powertop.service
[Unit]
Description=PowerTOP auto tune

[Service]
Type=idle
Environment="TERM=dumb"
User=admin
ExecStart=/usr/sbin/powertop --auto-tune

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable powertop.service

###################################################################
# Attended configuration
###################################################################

sudo protonvpn init

# Create SSH key for github.com and gitlab.com
# https://help.github.com/en/github/authenticating-to-github/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519.pub -C "noreply@pedro.pombei.ro"
xclip -sel clip < ~/.ssh/id_ed25519.pub
echo "Add the SSH key from keyboard to your GitLab account. Opening browser..."
open https://gitlab.com/profile/keys
echo "Press Return when done"
read -r

echo "Add the SSH key from keyboard to your GitHub account. Opening browser..."
open https://github.com/settings/keys
echo "Press Return when done"
read -r
