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
  - [Package Sources](#package-sources)
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

  - [zinit](https://github.com/zdharma-continuum/zinit) plugin manager with
    [Oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh) plugins
  - Custom aliases and functions for productivity
  - [fzf](https://github.com/junegunn/fzf) integration - fuzzy file finder (use `**<TAB>` for fuzzy completion,
    e.g., `vim **<TAB>`)
  - [zoxide](https://github.com/ajeetdsouza/zoxide) - smarter directory navigation
  - [mise](https://mise.jdx.dev/) - polyglot runtime manager and environment switcher

- **📝 Editor Configuration**

  - [Neovim](https://neovim.io/) with comprehensive plugin setup
  - [Neovide](https://neovide.dev/) - Neovim GUI client
  - Vim configuration with fzf integration
  - VS Code settings sync

- **🤖 Automation & Quality**

  - Pre-commit hooks for shell, markdown, Ruby, Lua, and formatting checks
  - CI validations (pre-commit, Neovim config load, luacheck, bootstrap lint, gitleaks)
  - Update scripts for brew, mise, zinit, and Neovim plugin health

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

After installing the dotfiles, ensure the Syncthing-managed config files are linked:

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

### Package Sources

The definitive list of packages lives in the Homebrew bundle file and App Store list:

- Homebrew brews and casks: `.Brewfile`
- Mac App Store apps: `.Brewfile` (`mas` entries)

The README highlights key tooling, but the Brewfile is the source of truth.

## Development Tools

Key tools included in this setup:

- **Version Manager:** [mise](https://mise.jdx.dev/) for runtime installs and CLI tooling
  (`node`, `ruby`, `go`, `redis`, plus linters and helpers)
- **Languages:** Ruby, Go, Node.js (plus tooling like `ruby-lsp`, `neovim-remote`, `renovate`, `markdownlint`)
- **Databases:** PostgreSQL (via `pgcli`, `pspg`, and `libpq`)
- **Containerization:** Docker, plus lightweight tooling for container ops
- **CLI Essentials:** ripgrep, fd, bat, eza, yazi, jq/yq, hyperfine, tealdeer
- **Git Tooling:** gh, git-delta, git-extras, git-peek, lazygit

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

**Update dotfiles tooling:**

```shell
~/.config/yadm/scripts/update.sh
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
