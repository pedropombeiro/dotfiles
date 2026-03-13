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

## Passthrough and iTerm2 OSC Sequences

The config uses `allow-passthrough all` (not just `on`) so that iTerm2 proprietary escape sequences
(badge, progress bar, notifications) are forwarded from **all** panes, not just the active one.
This is required for scripts like `mise run dotfiles:update` to show progress when running in a
background pane. The `on` setting only forwards passthrough from the currently focused pane.

## Yank Last Command Output (`prefix + y`)

Uses OSC 133 semantic prompt markers to select the output of the previous command and copy it
to the system clipboard via `pbcopy`. Requires iTerm2 shell integration to be active inside tmux.

**Dependencies:**

- `ITERM_ENABLE_SHELL_INTEGRATION_WITH_TMUX=YES` — set in `~/.shellrc/zshrc.d/configs/iterm2.zsh`
  so the iTerm2 shell integration script emits OSC 133 markers (`A`=prompt start, `B`=prompt end,
  `C`=command output start, `D`=command end) even under tmux
- `~/.iterm2_shell_integration.zsh` — sourced explicitly from the same file (iTerm2 only
  auto-injects it outside tmux)
- The binding uses `previous-prompt -o` / `next-prompt` copy-mode commands (tmux 3.4+)

**Note:** Only works in panes opened _after_ the shell integration is sourced. Pre-existing panes
won't have OSC 133 markers in their scrollback.

## Yank Current Command Text (`prefix + Y`)

Copies the text currently being typed on the zsh command line (`$BUFFER`) to the system clipboard.
Unlike `prefix + y` (which uses tmux copy-mode and OSC 133 markers), this operates at the shell
level via a zle widget and works regardless of scrollback state.

**How it works:**

1. `prefix + Y` in tmux sends the custom escape sequence `\e[Y` to the pane
2. zsh has a `yank-buffer-to-clipboard` zle widget bound to `\e[Y` in both `viins` and `vicmd` keymaps
3. The widget pipes `$BUFFER` to `pbcopy` and displays a confirmation message

**Files:**

- `~/.config/tmux/tmux.conf` — the `prefix + Y` binding (`send-keys Escape '[Y'`)
- `~/.shellrc/zshrc.d/configs/post/common-bindings.zsh` — the zle widget and keybinding

**Notes:**

- Shows "Nothing to copy" if the command line is empty
- Uses `clipcopy` (OMZ clipboard lib) for cross-platform support (`pbcopy` on macOS, OSC 52 on QNAP)

## OpenCode Tmux Tab Indicator

The opencode plugin `~/.config/opencode/plugins/tmux-indicator.js` sets a per-window user option
`@opencode-waiting` when an opencode instance is waiting for user input (permission or question).
The presentation is handled in `tmux.conf` via `#{?@opencode-waiting,...}` conditionals in
`window-status-format`, which turns inactive tabs gruvbox green with a `● ` prefix.

## Alt+Number Window Switching

`Alt+0` through `Alt+9` are bound in the root key table (`bind-key -n`) to jump directly to
window `:0`–`:9` without the prefix key. These bindings are placed **after** the TPM `run` line
to prevent plugins from overwriting them.

**iTerm2 caveat:** By default, iTerm2 maps `Alt+number` to its own split-pane navigation
(Settings → Keys → Navigation Shortcuts → "Shortcut to choose a split pane"). This intercepts
the keys before tmux sees them. Set that option to **"No Shortcut"** so the Alt+number keys
pass through to tmux.

## Editing Configuration

To modify tmux settings:

1. Edit `~/.config/tmux/tmux.conf` for universal settings
2. Edit `~/.config/tmux/tmux.platform.conf##distro.qts` for QNAP-specific overrides
3. Reload tmux: `tmux source-file ~/.config/tmux/tmux.conf` or `prefix + r` (if configured)
4. Commit changes with `yadm` (not `git`)

## Sesh Session Manager

Tmux integrates with `sesh` for session discovery and switching.

### Keybindings

- `prefix + T` opens the sesh picker in a tmux popup (fzf-tmux).
- `prefix + L` switches to the last active session using `sesh last`.

### Shell Integration

- `Alt + s` opens the sesh picker from the shell when not in tmux.
- Completion is generated via `sesh completion zsh` into `~/.config/zsh/site-functions/`.
