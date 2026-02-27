# Tmux Configuration

## Overview

The tmux configuration is managed through yadm. The main config is universal (works on all machines), with QNAP-specific terminal fixes in a local override file.

## Configuration Structure

### Main Configuration Files

Tmux automatically loads configuration from the XDG location `~/.config/tmux/tmux.conf`.

1. **`~/.config/tmux/tmux.conf`** (Universal config)

   - Shared across all machines
   - Features:
     - Mouse support enabled
     - Clipboard integration via OSC 52
     - Focus events and passthrough enabled
     - VI mode keys
     - Custom keybindings (mouse drag for window reordering, pane_current_path)
     - Plugin management via TPM (Tmux Plugin Manager)
   - Sources `~/.config/tmux/tmux.platform.conf` if it exists (for platform-specific overrides)

2. **`~/.config/tmux/tmux.platform.conf##distro.qts`** (QNAP overrides)

   - QNAP-specific terminal fixes, sourced by the main config
   - Features:
     - `xterm-keys on` for Ctrl-arrow compatibility
     - Home/End key fixes
     - `default-terminal "tmux-256color"` with italics and RGB overrides

3. **`~/.shellrc/zshrc.d/configs/tmux.zsh##distro.qts`** (Shell integration, QNAP only)

   - Shell-side tmux configuration for auto-starting tmux on QNAP
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
  - Left: `M-h`
  - Right: `M-l`
  - Up: `M-k`
  - Down: `M-j`
  - Previous: `M-\`
- `egel/tmux-gruvbox` - Gruvbox theme (dark256)
- `MunifTanjim/tmux-mode-indicator` - Shows WAIT/COPY/SYNC/TMUX mode in status bar

### Related Files

- **`~/.config/nvim/lua/plugins/vim-tmux-navigator.lua`**

  - Neovim integration for tmux navigation (universal, works on all machines)

- **`~/.config/yadm/bootstrap.d/910-install-tmux-plugin-manager.sh`**

  - Bootstrap script to install TPM and plugins (universal)

- **`~/.config/yadm/bootstrap.d/915-install-tmux-terminfo.sh##os.Linux,distro.qts`**
  - Bootstrap script to install tmux terminfo (QNAP/Linux only)

## Plugin Installation

Plugins are expected to be installed in `~/.tmux/plugins/` directory via TPM.
Installation command (within tmux): `prefix + I` (capital i)

## Important Notes

1. The main `tmux.conf` is universal — no yadm alternate suffix
2. Only the platform override (`tmux.platform.conf`) and shell integration (`tmux.zsh`) use yadm alternates for QNAP
3. Use `yadm` commands (not `git`) for version control
4. The opencode.nvim Neovim plugin auto-detects tmux and uses the tmux provider when `$TMUX` is set

## Editing Configuration

To modify tmux settings:

1. Edit `~/.config/tmux/tmux.conf` for universal settings
2. Edit `~/.config/tmux/tmux.platform.conf##distro.qts` for QNAP-specific overrides
3. Reload tmux: `tmux source-file ~/.config/tmux/tmux.conf` or `prefix + r` (if configured)
4. Commit changes with `yadm` (not `git`)
