# Tmux Configuration

## Overview

The tmux configuration is managed through yadm with multiple files working together to provide a complete setup.

## Configuration Structure

### Main Configuration Files

Tmux automatically loads configuration from the XDG location `~/.config/tmux/tmux.conf`.

1. **`~/.config/tmux/tmux.conf##distro.qts`** (Primary config)

   - The tmux configuration file with all settings
   - Location: `/Users/pedro/.config/tmux/tmux.conf##distro.qts`
   - Features:
     - Mouse support enabled
     - Clipboard integration via OSC 52
     - Focus events and passthrough enabled
     - Xterm-keys for QNAP compatibility
     - Italics and RGB color support
     - Custom keybindings (Home/End, mouse drag for window reordering)
     - Plugin management via TPM (Tmux Plugin Manager)

2. **`~/.shellrc/zshrc.d/configs/tmux.zsh##distro.qts`** (Shell integration)

   - Shell-side tmux configuration
   - Sets environment variables for tmux behavior:
     - `ZSH_TMUX_AUTOCONNECT=true`
     - `ZSH_TMUX_AUTOSTART=true`
     - `ZSH_TMUX_CONFIG` points to `~/.config/tmux/tmux.conf`
     - `ZSH_TMUX_DEFAULT_SESSION_NAME` set to hostname
   - Enables the oh-my-zsh tmux plugin

### Plugins Configured

The configuration uses TPM (Tmux Plugin Manager) with these plugins:

- `tmux-plugins/tpm` - Plugin manager itself
- `tmux-plugins/tmux-sensible` - Sensible defaults
- `tmux-plugins/tmux-pain-control` - Better pane control
- `alexwforsythe/tmux-which-key` - Keybinding helper
- `christoomey/vim-tmux-navigator` - Seamless vim/tmux navigation with custom mappings:
  - Left: `C-Left` or `M-h`
  - Right: `C-Right` or `M-l`
  - Up: `M-k`
  - Down: `M-j`
  - Previous: `M-\`
- `egel/tmux-gruvbox` - Gruvbox theme (dark256)

### Related Files

- **`~/.config/nvim/lua/plugins/vim-tmux-navigator.lua##distro.qts`**

  - Neovim integration for tmux navigation

- **`~/.config/yadm/bootstrap.d/92-install-tmux-plugin-manager.sh##os.Linux,distro.qts`**

  - Bootstrap script to install TPM (Linux only)

- **`~/.config/yadm/bootstrap.d/92-install-tmux-terminfo.sh##os.Linux,distro.qts`**
  - Bootstrap script to install tmux terminfo (Linux only)

## Plugin Installation

Plugins are expected to be installed in `~/.tmux/plugins/` directory via TPM.
Installation command (within tmux): `prefix + I` (capital i)

## Important Notes

1. All configuration files use yadm alternate file syntax (`##distro.qts`)
2. Use `yadm` commands (not `git`) for version control
3. The configuration is designed for the "qts" distro (QNAP)
4. Terminal type is set via `$ZSH_TMUX_TERM` environment variable
5. Status bar shows session name in format: `[session_name]`

## Editing Configuration

To modify tmux settings:

1. Edit `~/.config/tmux/tmux.conf##distro.qts`
2. Reload tmux: `tmux source-file ~/.config/tmux/tmux.conf` or `prefix + r` (if configured)
3. Commit changes with `yadm` (not `git`)
