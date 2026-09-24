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

3. **`~/.shellrc/zshrc.d/configs/tmux.zsh`** (Shared shell integration)
   - Configures the oh-my-zsh tmux plugin, config path, and hostname-based session name
   - `tmux.platform.zsh##distro.qts` enables automatic connection and startup on QNAP

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

- `opencode.nvim` selects its tmux provider when `$TMUX` is set.

- **`~/.config/nvim/lua/plugins/vim-tmux-navigator.lua`**
  - Neovim integration for tmux navigation (universal, works on all machines)

- **`~/.config/yadm/bootstrap.d/910-install-tmux-plugin-manager.sh`**
  - Bootstrap script to install TPM and plugins (universal)

- **`~/.config/yadm/bootstrap.d/915-install-tmux-terminfo.sh##os.Linux,distro.qts`**
  - Bootstrap script to install tmux terminfo (QNAP/Linux only)

## Plugin Installation

Plugins are expected to be installed in `~/.tmux/plugins/` directory via TPM.
Installation command (within tmux): `prefix + I` (capital i)

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

The opencode plugin `opencode-tmux-indicator` sets a per-window user option
`@opencode-waiting` when an opencode instance is waiting for user input (permission or question).
The presentation is handled in `tmux.conf` via `#{?@opencode-waiting,...}` conditionals in
`window-status-format`, which turns inactive tabs gruvbox green with a `● ` prefix.

The plugin also writes a BEL to the pane TTY so tmux sets `window_bell_flag`, enabling
`Prefix + M-n` (`next-window -a`) to jump to windows waiting for input. To prevent the bell
from forwarding to iTerm2 or overriding tab styling, `tmux.conf` sets `bell-action none` and
`window-status-bell-style default`.

`Hyper+A` (or `Caps Lock+A`) invokes `~/.local/bin/opencode-goto-waiting` through Hammerspoon.
It cycles through waiting OpenCode conversations in a stable tmux session/window/pane order,
including multiple conversations in one instance and tmux sessions that are
detached from every tmux client. Client selection prefers, in order: a client **already displaying
the target session**; the tab that **last displayed** it (its home tab, remembered in the
per-session `@opencode-home-tty` option); the frontmost tab; the most recently active client. This
keeps a session in the tab where it usually lives instead of dragging it into the frontmost tab,
including when the session is detached. Hammerspoon then activates iTerm2 and selects that tab.
The plugin publishes per-pane `@opencode-waiting-target-*` options containing private Unix
socket paths. The navigator queries `/waiting` and posts to `/select/SESSION_ID` to bring the
conversation to the front through the plugin's SDK client. The window indicator stays set
while any registered plugin instance in that window is waiting.

It stores its cycle cursor in tmux's global `@opencode-goto-cursor` option and removes stale
socket registrations. The same action is available at Hammerspoon's
`?action=opencode-goto` endpoint.

Both `cli.base.json` alternates configure `opencode-tmux-indicator`. Follow the
[plugin pinning policy](opencode.md#plugin-version-pinning) when updating it. Its source is in
`~/Developer/github.com/pedropombeiro/opencode-plugins/packages/tmux-indicator/`.

## Alt+Number Window Switching

`Alt+0` through `Alt+9` are bound in the root key table (`bind-key -n`) to jump directly to
window `:0`–`:9` without the prefix key. These bindings are placed **after** the TPM `run` line
to prevent plugins from overwriting them.

**iTerm2 caveat:** By default, iTerm2 maps `Alt+number` to its own split-pane navigation
(Settings → Keys → Navigation Shortcuts → "Shortcut to choose a split pane"). This intercepts
the keys before tmux sees them. Set that option to **"No Shortcut"** so the Alt+number keys
pass through to tmux.

## Running Commands in a Temporary Tmux Pane

Use the [`run-in-tmux-pane` skill](../skills/run-in-tmux-pane/SKILL.md) for
commands that need a TTY, zsh functions, or login-shell state. It owns the
execution decision rules, timeout settings, and usage reference.

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
- `fn + Tab` and `Caps Lock + L` (iTerm2 only) are alternatives to `prefix + L`, implemented in
  Hammerspoon. `Hyper + L` works too, via the same `hyperBind` registration.

### fn+Tab and Caps Lock+L last-session shortcuts

Both live in `~/.hammerspoon/hotkeys/sesh.lua`. They run
`tmux switch-client -c <frontmost iTerm2 tty> -l`, which is what `prefix + L` ends up doing.

The `fn`/Globe modifier is consumed by macOS and never reaches the terminal as an escape
sequence, so it **cannot** be bound in `tmux.conf`. `hs.hotkey.bind` also rejects `fn` as a
modifier, so the module uses a raw `hs.eventtap` that inspects `event:getFlags()` on the Tab
keycode. `Caps Lock + L` goes through the existing `hyperBind` helper in `hotkeys/hyperkey.lua`.

Notes:

- The `fn` tap matches `containExactly({ "fn" })`, so `cmd+fn+Tab` and similar pass through.
- Both are scoped to the iTerm2 bundle ID, so the keys are untouched in other apps.
- `-c <tty>` is required: each tmux client tracks its own `client_last_session`, so omitting it
  switches the most recently active client rather than the tab in front of you.
- `fn` only exists on Apple keyboards. On external non-Apple keyboards use `Caps Lock + L` or
  `prefix + L`.
- The shortcuts deliberately do **not** synthesize `prefix + L` keystrokes; see the Hammerspoon
  skill for why that recurses.

### Shell Integration

- `Alt + s` opens the sesh picker from the shell when not in tmux.
- Completion is generated via `sesh completion zsh` into `~/.config/zsh/site-functions/`.
