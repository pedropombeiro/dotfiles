<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
# Table of Contents

- [Prerequisites](#prerequisites)
  - [Mac OS X](#mac-os-x)
  - [Linux Debian/Ubuntu](#linux-debianubuntu)
- [Installation](#installation)
- [Post-install procedure](#post-install-procedure)
  - [On a fresh installation - Linux](#on-a-fresh-installation---linux)
  - [On a fresh installation - Mac OS X](#on-a-fresh-installation---mac-os-x)
    - [After factory reset](#after-factory-reset)
    - [Mac OS X Settings](#mac-os-x-settings)
    - [Apps to install](#apps-to-install)
- [Features](#features)
- [Misc](#misc)
  - [Profiling ZSH](#profiling-zsh)
  - [Useful software (not installed by default)](#useful-software-not-installed-by-default)
  - [Checklist before reinstall](#checklist-before-reinstall)
- [Acknowledgments](#acknowledgments)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Prerequisites

## Mac OS X

Install the [Brew package manager](https://brew.sh/):

```shell
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
```

Install dependencies:

```shell
sudo softwareupdate -i -a
# The Xcode Command Line Tools includes git and make (not available on stock macOS)
xcode-select --install
```

See [Installation](#Installation) and then the [fresh install section](#on-a-fresh-installation---mac-os-x) below.

## Linux Debian/Ubuntu

```shell
sudo apt install build-essential curl file git make

# Install Homebrew
sudo /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
test -r ~/.bash_profile.local && echo "eval \$($(brew --prefix)/bin/brew shellenv)" >> ~/.bash_profile.local
echo "eval \$($(brew --prefix)/bin/brew shellenv)" >> ~/.profile.local
```

# Installation

This dotfiles environment is based on https://www.atlassian.com/git/tutorials/dotfiles.

To check out this repo and automatically back up any existing dotenv files, run:

```shell
curl -Lks https://gitlab.com/pedropombeiro/dotfiles/snippets/1960043/raw | /bin/bash
```

# Post-install procedure

To install all the required software, run [make install](./.install/linux/install.sh)

```shell
make install

# VirtualBox requires special permissions for its kernel extension to work
# so installation will fail the first time, until you enable the permission
# in System Preferences (just retry again after enabling permission)
brew cask install virtualbox virtualbox-extension-pack

nvm install --lts --latest-npm

npm install -g doctoc
```

## On a fresh installation - Linux

```shell
# Verify you can connect to github and gitlab with the generated SSH keys:
ssh -T git@github.com
ssh -T git@gitlab.com
```

## On a fresh installation - Mac OS X

### After factory reset

1. Install any OS upgrade
1. Install XCode from the App Store. Open it and accept the T&C.
1. Run the steps below

```shell
# Verify you can connect to github and gitlab with the generated SSH keys:
ssh -T git@github.com
ssh -T git@gitlab.com
```

### Mac OS X Settings

- Change the computer name
- Change the default terminal font to 'MesloLGS NF'
- [Disable notifications when screen is off](https://www.jeffgeerling.com/blog/2016/external-display-waking-disable-notifications-when-your-screen)
- Disable Location Services
- Set keyboard shortcuts
  - Set the change input source shortcuts

### Apps to install

- Installed via brew:
  - [1Password](https://1password.com/downloads/mac/)
  - [Beyond Compare](https://scootersoftware.com/download.php)
  - [CheatSheet](https://www.mediaatelier.com/CheatSheet/)
  - [Dash](https://kapeli.com/dash)
  - [Docker](https://www.docker.com/products/docker-desktop)
  - [Dropbox](https://www.dropbox.com/install)
  - [Fork Git client](https://git-fork.com/update/files/Fork.dmg)
  - [Google Chrome](https://www.google.com/chrome/)
  - [iTerm2](https://www.iterm2.com/downloads.html)
  - [ItsyCal](https://www.mowglii.com/itsycal/)
  - [Krisp](https://krisp.ai/)
  - [LibreOffice](https://www.libreoffice.org/download/download/)
  - [MacPass](https://macpassapp.org/)
  - [Mac App Store command line interface](https://github.com/mas-cli/mas)
  - [Mackup](https://github.com/lra/mackup)
  - [Midnight Commander](https://midnight-commander.org/)
  - [Microsoft Edge](https://www.microsoft.com/en-us/edge)
  - [Muzzle](https://muzzleapp.com/)
  - [Numi](https://numi.io/)
  - [P4Merge](https://www.perforce.com/products/helix-core-apps/merge-diff-tool-p4merge)
  - [Plex](https://www.plex.tv/media-server-downloads/#plex-app)
  - [ProtonMail Bridge](https://protonmail.com/bridge/install)
  - [ProtonVPN](https://protonvpn.com/download)
  - [RecordIt](http://www.recordit.co/)
  - [Skype](https://www.skype.com/en/get-skype/)
  - [Slack](https://slack.com/downloads)
  - [Spotify](https://www.spotify.com/download/mac)
  - [Syncthing](https://syncthing.net/downloads/)
  - [TripMode 2](https://www.tripmode.ch/)
  - [Visual Studio Code](https://code.visualstudio.com/Download)
- Installed via mas-cli:
  - Amphetamine ([App Store](https://apps.apple.com/us/app/amphetamine/id937984704))
  - Annotate ([App Store](https://apps.apple.com/us/app/annotate-text-emoji-stickers-shapes-on-photos-screenshots/id994933038))
  - Be Focused ([App Store](https://apps.apple.com/us/app/be-focused-focus-timer/id973130201))
  - Feedly ([App Store](https://apps.apple.com/us/app/feedly-read-more-know-more/id865500966))
  - Keynote ([App Store](https://apps.apple.com/us/app/keynote/id409183694))
  - Numbers ([App Store](https://apps.apple.com/us/app/numbers/id409203825))
  - Pages ([App Store](https://apps.apple.com/us/app/pages/id409203825))
  - Pocket ([App Store](https://apps.apple.com/us/app/pocket/id568494494))
  - Simplenote ([App Store](https://apps.apple.com/us/app/simplenote/id692867256))
  - Toggl Desktop ([App Store](https://apps.apple.com/us/app/toggl-time-tracker-for-work/id957734279))
  - TweetDeck ([App Store](https://apps.apple.com/us/app/tweetdeck-by-twitter/id485812721))
  - WhatsApp ([App Store](https://apps.apple.com/us/app/whatsapp-desktop/id1147396723))
- [Elgato Control Center](https://www.elgato.com/en/gaming/downloads)
- [Microsoft To Do](https://todo.microsoft.com/tasks/)
- [Oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh) (installed via curl/git clone)
- [OpenVPN](https://vpn.pombei.ro/?src=connect)
- [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
- GitLab-specific:
  - [Install GitLink](https://plugins.jetbrains.com/plugin/8183-gitlink)

Setup the following apps:

- Beyond Compare (import settings backup and install command line tools)
- Dropbox
- Password application
  - 1Password
  - MacPass
- Syncthing
- Time Machine
- Microsoft Edge
- Visual Studio Code
  - Install [Settings Sync plugin](https://marketplace.visualstudio.com/items?itemName=Shan.code-settings-sync)
- Printers
- Be Focused
  - Work interval duration: 20m
  - Short break duration: 1m
  - Long break duration: 15m
  - Long break after: 6 intervals
  - Target: 18 intervals

# Features

- [fzf](https://github.com/junegunn/fzf): fuzzy file finder. To use it on the command line, prefix with `**`, then press tab. For instance: `vim **<TAB>`.
- [autojump](https://github.com/wting/autojump): a cd commands that learns
  about your favorite directories.

# Misc

## Profiling ZSH

Use `zprof`:

```shell
# At the beginning of your file, e.g. zshrc
zmodload zsh/zprof

...

# At the end:
zprof
```

## Useful software (not installed by default)

## Checklist before reinstall

- Backup SSH keys
- Check each app for backup
- Backup hidden files in repo
- Backup `/Library/`
- Backup `~/Library/`
- Make sure branches in repo are pushed
- Search for "what folders to backup"
- Search for "checklist before factory reset"
- Make sure iCloud sync is finished (check status bar in Finder)
- What's most important? Is it backed up?

# Acknowledgments

- [holman](https://github.com/holman/dotfiles)
- [thoughtbot](https://github.com/thoughtbot/dotfiles)
- [conf.d like directories for zsh/bash dotfiles](https://chr4.org/blog/2014/09/10/conf-dot-d-like-directories-for-zsh-slash-bash-dotfiles/)
