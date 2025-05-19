<!--toc:start-->
- [Abstract](#abstract)
- [Prerequisites](#prerequisites)
  - [Mac OS X](#mac-os-x)
  - [Installation](#installation)
  - [Linux Debian/Ubuntu](#linux-debianubuntu)
- [Post-install procedure](#post-install-procedure)
  - [On a fresh installation - Linux](#on-a-fresh-installation-linux)
  - [On a fresh installation - Mac OS X](#on-a-fresh-installation-mac-os-x)
    - [After factory reset](#after-factory-reset)
    - [Mac OS X Settings](#mac-os-x-settings)
    - [Apps to install](#apps-to-install)
- [Features](#features)
- [Misc](#misc)
  - [Profiling ZSH](#profiling-zsh)
  - [Useful software (not installed by default)](#useful-software-not-installed-by-default)
  - [Checklist before reinstall](#checklist-before-reinstall)
  - [Checklist after install](#checklist-after-install)
  - [Useful commands](#useful-commands)
    - [Use vim in YADM Git context](#use-vim-in-yadm-git-context)
- [Acknowledgments](#acknowledgments)
<!--toc:end-->

| Label | Screenshot |
| ----- | ---------- |
| Oh-my-zsh | <img width="800" alt="image" src="https://github.com/pedropombeiro/dotfiles/assets/138074/170565d5-e6cc-45f3-bfcc-2a114d8be5bf"> |
| Vifm      | <img width="800" alt="image" src="https://github.com/pedropombeiro/dotfiles/assets/138074/9c58e32f-6791-4d91-a5a7-a362ba124582"> |
| Neovim    | <img width="1582" alt="image" src="https://github.com/pedropombeiro/dotfiles/assets/138074/a72f5baa-53ca-4e66-8e04-29be19cfd6bf"> |

# Abstract

This dotfiles repo leverages [YADM](https://yadm.io/) as the dotfiles manager.

# Prerequisites

## Mac OS X

Log in to the App Store.

Install the YADM and the [Brew package manager](https://brew.sh/):

```shell
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
brew install yadm
```

## Installation

Install dotfiles:

```shell
# Use HTTPS protocol for anonymous access
yadm clone --no-bootstrap https://github.com/pedropombeiro/dotfiles.git && \
yadm config local.class Personal && \
yadm bootstrap && \
source ~/.zshrc.shared
```

See the [fresh install section](#on-a-fresh-installation---mac-os-x) below.

## Linux Debian/Ubuntu

```shell
sudo apt update && sudo apt install -y yadm
```

Install dotfiles:

```shell
yadm clone --no-bootstrap https://github.com/pedropombeiro/dotfiles.git && \
yadm config local.class Personal && \
yadm bootstrap && \
source ~/.zshrc.shared
```

# Post-install procedure

```shell
# Symlink the dotfiles in Syncthing
~/.config/yadm/scripts/relink-dotfiles.sh
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

1. After doing the first sync with Syncthing, restore Mackup backup:

```shell
mackup restore
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
  - [Alfred](https://www.alfredapp.com/)
  - [Beyond Compare](https://scootersoftware.com/download.php)
  - [Boom 3D](https://www.globaldelight.com/boom/)
  - [Camera Live](https://github.com/v002/v002-Camera-Live)
  - [Croc file transfer](https://github.com/schollz/croc)
  - [Dash](https://kapeli.com/dash)
  - [Docker](https://www.docker.com/products/docker-desktop)
  - [Dropbox](https://www.dropbox.com/install)
  - [Fork Git client](https://git-fork.com/update/files/Fork.dmg)
  - [Google Chrome](https://www.google.com/chrome/)
  - [iTerm2](https://www.iterm2.com/downloads.html)
  - [Kap](https://getkap.co/)
  - [Krisp](https://krisp.ai/)
  - [LibreOffice](https://www.libreoffice.org/download/download/)
  - [Little Snitch](https://www.obdev.at/products/littlesnitch/download.html)
  - [Mac App Store command line interface](https://github.com/mas-cli/mas)
  - [Mackup](https://github.com/lra/mackup)
  - [Microsoft Edge](https://www.microsoft.com/en-us/edge)
  - [Muzzle](https://muzzleapp.com/)
  - [Notion](https://notion.so)
  - [Numi](https://numi.io/)
  - [P4Merge](https://www.perforce.com/products/helix-core-apps/merge-diff-tool-p4merge)
  - [Plex](https://www.plex.tv/media-server-downloads/#plex-app)
  - [ProtonMail Bridge](https://protonmail.com/bridge/install)
  - [ProtonVPN](https://protonvpn.com/download)
  - [Skype](https://www.skype.com/en/get-skype/)
  - [Slack](https://slack.com/downloads)
  - [Spotify](https://www.spotify.com/download/mac)
  - [Syncthing](https://syncthing.net/downloads/)
  - [switchaudio-osx](https://github.com/deweller/switchaudio-osx)
  - [TripMode 3](https://www.tripmode.ch/)
  - [Visual Studio Code](https://code.visualstudio.com/Download)
- Installed via mas-cli:
  - Amphetamine ([App Store](https://apps.apple.com/us/app/amphetamine/id937984704))
  - Pocket ([App Store](https://apps.apple.com/us/app/pocket/id568494494))
  - Toggl Desktop ([App Store](https://apps.apple.com/us/app/toggl-time-tracker-for-work/id957734279))
  - Time Out - Break Reminders ([App Store](https://apps.apple.com/us/app/time-out-break-reminders/id402592703))
  - WhatsApp ([App Store](https://apps.apple.com/us/app/whatsapp-desktop/id1147396723))
- [Elgato Control Center](https://www.elgato.com/en/gaming/downloads)
- [Microsoft To Do](https://todo.microsoft.com/tasks/)
- [Oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh) (installed via curl/git clone)
- [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
- GitLab-specific:
  - [Install GitLink](https://plugins.jetbrains.com/plugin/8183-gitlink)

Setup the following apps:

- Beyond Compare (import settings backup and install command line tools)
- Password application
  - 1Password
  - MacPass
- Syncthing
- Time Machine
- Microsoft Edge
- Visual Studio Code
  - Enable settings sync
- Printers
- Time Out
  - Name: Pomodoro
  - Pomodoro time: 20m
  - Break time: 1m
  - Theme: Muscles
  - Show button to postpone: 1 minutes
  - Show button to postpone: 5 minutes
  - Show button to skip break

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

- Make Time Machine or SuperDuper! backup
- Check each app for backup
- Backup hidden files in repo
- Make sure branches in repo are pushed
- Search for "what folders to backup"
- Search for "checklist before factory reset"
- Make sure iCloud sync is finished (check status bar in Finder)
- What's most important? Is it backed up?

## Checklist after install

- Add Terminal, iTerm, Visual Studio Code, RubyMine, and GoLand to `System Preferences/Security & Privacy/Privacy/Developer Tools` list, to avoid Apple notarisation checks that cause slowdowns.
- Configure [`$HOME/.git-peek`](https://awesomeopensource.com/project/Jarred-Sumner/git-peek#private-repositories--choosing-an-editor)
- Copy relevant folders from backup, under `~/Library/Application Support` and `~/Library/Preferences`

## Useful commands

### Use vim in YADM Git context

Running vim from inside yadm ensures that integration with fzf.vim works correctly, and the Git worktree is correctly configured:

```shell
yadm enter vim
```

# Acknowledgments

- [holman](https://github.com/holman/dotfiles)
- [thoughtbot](https://github.com/thoughtbot/dotfiles)
- [conf.d like directories for zsh/bash dotfiles](https://chr4.org/blog/2014/09/10/conf-dot-d-like-directories-for-zsh-slash-bash-dotfiles/)
