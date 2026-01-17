# Pedro's Dotfiles 🛠️

A comprehensive dotfiles configuration managed with [YADM](https://yadm.io/) for macOS and Linux systems,
featuring a carefully curated development environment with powerful CLI tools and integrations.

<!--toc:start-->

- [Overview](#overview)
- [Screenshots](#screenshots)
- [Features](#features)
- [Quick Start](#quick-start)
  - [macOS](#macos)
  - [Linux (Debian/Ubuntu)](#linux-debianubuntu)
- [Post-Installation](#post-installation)
  - [Fresh Installation - macOS](#fresh-installation---macos)
  - [Fresh Installation - Linux](#fresh-installation---linux)
- [Configuration](#configuration)
  - [macOS Settings](#macos-settings)
  - [Apps to Install](#apps-to-install)
- [Development Tools](#development-tools)
- [Maintenance](#maintenance)
  - [Profiling ZSH](#profiling-zsh)
  - [Checklist Before Reinstall](#checklist-before-reinstall)
  - [Checklist After Install](#checklist-after-install)
  - [Useful Commands](#useful-commands)
- [Acknowledgments](#acknowledgments)
<!--toc:end-->

## Overview

This repository contains my personal dotfiles configuration, providing a consistent and productive development
environment across different machines. It uses YADM (Yet Another Dotfiles Manager) for seamless synchronization
and supports both macOS and Linux platforms with platform-specific configurations.

## Screenshots

| Tool       | Preview                      |
| ---------- | ---------------------------- |
| **Zsh**    | ![Zsh][zsh-screenshot]       |
| **Yazi**   | ![Yazi][yazi-screenshot]     |
| **Neovim** | ![Neovim][neovim-screenshot] |

[zsh-screenshot]: https://github.com/pedropombeiro/dotfiles/assets/138074/170565d5-e6cc-45f3-bfcc-2a114d8be5bf
[yazi-screenshot]: https://github.com/user-attachments/assets/e32158c3-5bd4-46ff-8155-c99e2eabb536
[neovim-screenshot]: https://github.com/user-attachments/assets/6d3479cb-c82e-475b-aafe-a7ef06d4e85a

## Features

This dotfiles setup includes:

- **🐚 Shell Configuration**

  - [zinit](https://github.com/zdharma-continuum/zinit) plugin manager with [Oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh) plugins
  - Custom aliases and functions for productivity
  - [fzf](https://github.com/junegunn/fzf) integration - fuzzy file finder (use `**<TAB>` for fuzzy completion,
    e.g., `vim **<TAB>`)
  - [autojump](https://github.com/wting/autojump) - intelligent directory navigation
  - [mise](https://mise.jdx.dev/) - polyglot runtime manager and environment switcher

- **📝 Editor Configuration**

  - [Neovim](https://neovim.io/) with comprehensive plugin setup
  - [Neovide](https://neovide.dev/) - Neovim GUI client
  - Vim configuration with fzf integration
  - VS Code settings sync

- **🔧 Development Tools**

  - Git configuration with aliases and utilities ([git-extras](https://github.com/tj/git-extras),
    [git-delta](https://github.com/dandavison/delta), [git-peek](https://github.com/Jarred-Sumner/git-peek))
  - Programming language environments (Ruby, Go, Python, Node.js, Rust)
  - [Docker](https://www.docker.com/) and [Colima](https://github.com/abiosoft/colima) for container development
  - Database tools (PostgreSQL with [pgcli](https://www.pgcli.com/), [pspg](https://github.com/okbob/pspg))

- **🎨 Terminal Enhancements**

  - [iTerm2](https://iterm2.com/) with shell integration
  - Custom color schemes
  - [Yazi](https://github.com/sxyazi/yazi) - blazing fast terminal file manager
  - [bat](https://github.com/sharkdp/bat) - cat clone with syntax highlighting
  - [eza](https://github.com/eza-community/eza) - modern replacement for ls
  - [btop](https://github.com/aristocratos/btop) - resource monitor
  - [grc](https://github.com/garabik/grc) - generic colouriser

- **📦 Package Management**

  - [Homebrew](https://brew.sh/) bundle configuration
  - [mise](https://mise.jdx.dev/) - polyglot runtime manager (modern alternative to asdf)
  - Language-specific package managers

- **🔐 Security & Privacy**
  - [1Password](https://1password.com/) with CLI integration
  - SSH configuration
  - GPG setup
  - Secure credential management

## Quick Start

### macOS

**Prerequisites:**

1. Log in to the App Store
2. Install Xcode and accept the license agreement

**Installation:**

```shell
# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"

# Install YADM
brew install yadm

# Clone dotfiles repository
yadm clone --no-bootstrap https://github.com/pedropombeiro/dotfiles.git

# Set class configuration (Personal or Work)
yadm config local.class Personal

# Run bootstrap script to set up environment
yadm bootstrap

# Reload shell configuration
source ~/.zshrc.shared
```

### Linux (Debian/Ubuntu)

```shell
# Install YADM
sudo apt update && sudo apt install -y yadm

# Clone dotfiles and bootstrap
yadm clone --no-bootstrap https://github.com/pedropombeiro/dotfiles.git
yadm config local.class Personal
yadm bootstrap
source ~/.zshrc.shared
```

## Post-Installation

After installing the dotfiles, symlink the configuration files in Syncthing:

```shell
~/.config/yadm/scripts/relink-dotfiles.sh
```

### Fresh Installation - macOS

**After Factory Reset:**

1. Install any available OS upgrades
2. Install Xcode from the App Store and accept the T&C
3. Run the quick start installation steps above
4. Verify SSH connectivity:

   ```shell
   ssh -T git@github.com
   ssh -T git@gitlab.com
   ```

5. After first Syncthing sync, restore Mackup backup:

   ```shell
   mackup restore
   ```

### Fresh Installation - Linux

Verify SSH connectivity to Git services:

```shell
ssh -T git@github.com
ssh -T git@gitlab.com
```

## Configuration

### macOS Settings

Manual configuration steps:

- Change the computer name in System Preferences
- Set default terminal font to 'MesloLGS NF'
- [Disable notifications when screen is off](https://www.jeffgeerling.com/blog/2016/external-display-waking-disable-notifications-when-your-screen)
- Disable Location Services (if desired)
- Configure keyboard shortcuts:
  - Set input source switching shortcuts

### Apps to Install

**Installed via Homebrew:**

_Productivity & Utilities:_

- [1Password](https://1password.com/) - Password manager with CLI support
- [Alfred](https://www.alfredapp.com/) - Productivity launcher
- [Raycast](https://raycast.com/) - Launcher and productivity tool
- [Bartender](https://www.macbartender.com/) - Menu bar organizer
- [Mackup](https://github.com/lra/mackup) - Application settings backup
- [Muzzle](https://muzzleapp.com/) - Notification manager for screen sharing
- [Notion](https://notion.so) - Note-taking and collaboration
- [AirBuddy](https://airbuddy.app/) - AirPods companion app

_Development Tools:_

- [Visual Studio Code](https://code.visualstudio.com/) - Code editor
- [iTerm2](https://iterm2.com/) - Terminal emulator
- [Fork](https://git-fork.com/) - Git client
- [TablePlus](https://tableplus.com/) - Database client
- [Docker](https://www.docker.com/products/docker-desktop) - Container platform
- [Dash](https://kapeli.com/dash) - API documentation browser
- [Neovide](https://neovide.dev/) - Neovim GUI client

_File Management & Comparison:_

- [Beyond Compare](https://scootersoftware.com/) - File/folder comparison
- [P4V](https://www.perforce.com/products/helix-core-apps/merge-diff-tool-p4merge) - Perforce visual client
- [The Unarchiver](https://theunarchiver.com/) - Archive extraction
- [Syncthing](https://syncthing.net/) - File synchronization
- [DaisyDisk](https://daisydiskapp.com/) - Disk space visualizer

_Media & Entertainment:_

- [Spotify](https://www.spotify.com/) - Music streaming
- [Plex](https://www.plex.tv/) - Media server
- [VLC](https://www.videolan.org/vlc/) - Multimedia player
- [Calibre](https://calibre-ebook.com/) - E-book management
- [GIMP](https://www.gimp.org/) - Image editor
- [MuseScore](https://musescore.org/) - Music notation software

_System Tools & Utilities:_

- [iStat Menus](https://bjango.com/mac/istatmenus/) - System monitoring
- [Lunar](https://lunar.fyi/) - Adaptive brightness for external displays
- [AppCleaner](https://freemacsoft.net/appcleaner/) - Application uninstaller
- [Stay](https://cordlessdog.com/stay/) - Window manager
- [Contexts](https://contexts.co/) - Window switcher
- [Input Source Pro](https://inputsource.pro/) - Multi-language input tool

_Web Browsers:_

- [Microsoft Edge](https://www.microsoft.com/edge) - Chromium-based browser
- [Firefox](https://www.firefox.com/) - Privacy-focused browser

_Communication:_

- [Slack](https://slack.com/) - Team communication
- [WhatsApp](https://www.whatsapp.com/) - Messaging
- [Zoom](https://zoom.us/) - Video conferencing

_Hardware & Specialty Tools:_

- [Elgato Stream Deck](https://www.elgato.com/stream-deck) - Customizable control pad
- [Garmin Express](https://www.garmin.com/express) - Garmin device management
- [Raspberry Pi Imager](https://www.raspberrypi.com/software/) - OS imaging tool
- [balenaEtcher](https://www.balena.io/etcher/) - USB/SD card flasher
- [ApplePi-Baker](https://www.tweaking4all.com/software/macosx-software/applepi-baker-v2/) - SD card backup/restore
- [YubiKey Manager](https://www.yubico.com/support/download/yubikey-manager/) - YubiKey configuration

_Networking & Security:_

- [ProtonVPN](https://protonvpn.com/) - VPN client
- [BlueSnooze](https://github.com/odlp/bluesnooze) - Bluetooth sleep blocker
- [Bluetility](https://github.com/jnross/Bluetility) - BLE browser

_Misc:_

- [Kap](https://getkap.co/) - Screen recorder
- [Shottr](https://shottr.cc/) - Screenshot annotation tool
- [UTM](https://mac.getutm.app/) - Virtual machines
- [EQMac](https://eqmac.app/) - System-wide equalizer
- [NetSpot](https://www.netspotapp.com/) - WiFi analyzer
- [Google Earth Pro](https://www.google.com/earth/about/versions/)
- [MediaInfo](https://mediaarea.net/en/MediaInfo)

**Installed via mas-cli (Mac App Store):**

- [1Password for Safari](https://apps.apple.com/app/id1569813296) - Safari extension
- [Amphetamine](https://apps.apple.com/app/id937984704) - Keep Mac awake
- [Kindle](https://apps.apple.com/app/id302584613) - E-book reader
- [WireGuard](https://apps.apple.com/app/id1451685025) - VPN client
- [Parcel](https://apps.apple.com/app/id375589283) - Package tracking
- [Mactracker](https://apps.apple.com/app/id430255202) - Apple hardware database
- [Discovery](https://apps.apple.com/app/id1381004916) - Bonjour browser

**Post-Installation Setup:**

Configure the following applications:

- **Beyond Compare** - Import settings backup and install command line tools
- **Password Manager** - Set up 1Password
- **Syncthing** - Configure synchronization
- **Time Machine** - Set up backups
- **Microsoft Edge** - Configure browser settings
- **Visual Studio Code** - Enable settings sync
- **Printers** - Add network/local printers

## Development Tools

Key tools included in this setup:

- **Version Managers:** [mise](https://mise.jdx.dev/) (formerly rtx/asdf alternative)
- **Languages:** Ruby, Go, Python, Node.js, Rust
- **Databases:**
  - PostgreSQL ([pgcli](https://www.pgcli.com/), [pspg](https://github.com/okbob/pspg), [libpq](https://www.postgresql.org/docs/current/libpq.html))
- **Containerization:**
  - [Docker](https://www.docker.com/)
  - [Colima](https://github.com/abiosoft/colima) - container runtime for macOS
  - [lazydocker](https://github.com/jesseduffield/lazydocker) - terminal UI for Docker
  - [ctop](https://github.com/bcicen/ctop) - top-like interface for containers
- **CLI Tools:**
  - **Search & Find:** [ripgrep](https://github.com/BurntSushi/ripgrep), [fd](https://github.com/sharkdp/fd),
    [the_silver_searcher](https://github.com/ggreer/the_silver_searcher)
  - **File Viewers:** [bat](https://github.com/sharkdp/bat),
    [highlight](http://www.andre-simon.de/doku/highlight/en/highlight.php), [vimpager](https://github.com/rkitover/vimpager)
  - **File Management:** [yazi](https://github.com/sxyazi/yazi)
  - **System Monitoring:** [btop](https://github.com/aristocratos/btop), [htop](https://htop.dev/), [viddy](https://github.com/sachaos/viddy)
  - **Disk Usage:** [ncdu](https://dev.yorhel.nl/ncdu), [dust](https://github.com/bootandy/dust), [duf](https://github.com/muesli/duf)
  - **Network Tools:** [gping](https://github.com/orf/gping), [dog](https://dns.lookup.dog/), [nmap](https://nmap.org/),
    [wireshark](https://www.wireshark.org/), [fping](https://fping.org/)
  - **Data Processing:** [jq](https://stedolan.github.io/jq/), [yq](https://github.com/mikefarah/yq),
    [miller](https://miller.readthedocs.io/), [visidata](https://www.visidata.org/), [jless](https://jless.io/)
  - **Benchmarking:** [hyperfine](https://github.com/sharkdp/hyperfine)
  - **Documentation:** [tealdeer](https://github.com/dbrgn/tealdeer) (tldr client)
- **Git Tools:**
  - [lazygit](https://github.com/jesseduffield/lazygit) - terminal UI for git
  - [gh](https://cli.github.com/) - GitHub CLI
  - [git-delta](https://github.com/dandavison/delta) - syntax-highlighting pager
  - [git-extras](https://github.com/tj/git-extras) - additional git utilities
  - [git-peek](https://github.com/Jarred-Sumner/git-peek) - instantly open remote repos
  - [Fork](https://git-fork.com/) - GUI Git client
- **Productivity:**
  - [croc](https://github.com/schollz/croc) - secure file transfer
  - [asciinema](https://asciinema.org/) - terminal session recorder
  - [entr](https://eradman.com/entrproject/) - run commands when files change

## Maintenance

### Profiling ZSH

To identify slow startup times, use `zprof`:

```shell
# Add at the beginning of your .zshrc
zmodload zsh/zprof

# ... your configuration ...

# Add at the end
zprof
```

### Checklist Before Reinstall

- [ ] Create Time Machine or SuperDuper! backup
- [ ] Verify application-specific backups
- [ ] Backup hidden files in repository
- [ ] Push all Git branches
- [ ] Search for "what folders to backup"
- [ ] Verify iCloud sync is complete (check Finder status bar)
- [ ] Confirm all critical data is backed up

### Checklist After Install

- [ ] Add Terminal, iTerm, VS Code, and IDEs to `System Preferences → Security & Privacy → Privacy → Developer Tools`
      to avoid Apple notarization slowdowns
- [ ] Configure [`$HOME/.git-peek`](https://awesomeopensource.com/project/Jarred-Sumner/git-peek#private-repositories--choosing-an-editor)
      for repository peeking
- [ ] Restore relevant folders from backup under `~/Library/Application Support` and `~/Library/Preferences`

### Useful Commands

**Use Vim in YADM Git context:**

Running vim from inside YADM ensures proper fzf.vim integration and Git worktree configuration:

```shell
yadm enter vim
```

**Update all packages:**

```shell
brew update && brew upgrade && brew cleanup
```

**Check YADM status:**

```shell
yadm status
yadm diff
```

## Acknowledgments

This dotfiles configuration was inspired by and builds upon ideas from:

- [holman/dotfiles](https://github.com/holman/dotfiles)
- [thoughtbot/dotfiles](https://github.com/thoughtbot/dotfiles)
- [conf.d like directories for zsh/bash dotfiles](https://chr4.org/blog/2014/09/10/conf-dot-d-like-directories-for-zsh-slash-bash-dotfiles/)

---

**License:** See [LICENSE](LICENSE) file for details
