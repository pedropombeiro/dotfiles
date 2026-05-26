# Shell Configuration

Zsh configuration with modular structure and zinit plugins.

## Structure

```
~/.shellrc/
├── zshrc.d/
│   ├── configs/
│   │   ├── pre/          # Early-load (zinit, mise, brew)
│   │   ├── [main]        # Core configs
│   │   └── post/         # Late-load (keybindings, fzf)
│   └── functions/        # Autoloaded shell functions
└── rc.d/                 # Shared bash/zsh configs
```

## Key Files

- `~/.zshenv` - Environment variables for all zsh sessions (loads earliest)
- `~/.zshrc.shared` - Main zsh entry point
- `~/.shellrc/zshrc.d/configs/zinit.zsh` - Plugin manager setup
- `~/.shellrc/zshrc.d/configs/post/keybindings.zsh` - Key mappings

## Loading Order

1. `~/.zshenv` loads first (env vars, before any interactive config)
2. `pre/` configs load next (zinit, mise, brew)
3. Main configs in `configs/` directory
4. `post/` configs load last (keybindings, fzf integration)

## PATH Ordering (macOS)

macOS `path_helper` (via `/etc/zprofile`) can push Homebrew and mise paths
behind `/usr/bin`. `pre/050-fix-path-ordering.zsh` restores the intended
priority so completion scripts (like Homebrew's `_git`) match the selected
binary:

`mise installs` > `mise shims` > `~/.local/bin` > `Homebrew` > `system`

## XDG Base Directories

`~/.zshenv` exports `XDG_CONFIG_HOME=~/.config` so that macOS CLI tools using
Go XDG libraries (`adrg/xdg`, `OpenPeeDeeP/xdg`) resolve config to `~/.config/`
instead of `~/Library/Application Support/`. This allows dotfile tracking via yadm.

Tools unaffected (use Rust `dirs` crate, ignores XDG on macOS): rtk, zoxide, neovide (settings).

## Alternate Files

Use platform-specific suffixes:

- `##distro.qts` - QNAP QTS
- `##os.Darwin` - macOS
- `##os.Linux` - Generic Linux
- `##class.Work` - Work-specific configs

## Adding Functions

Create files in `~/.shellrc/zshrc.d/functions/`:

- One function per file
- Filename = function name
- No file extension needed
- Functions are autoloaded on first use

## Plugin Load Order (zinit turbo)

Plugins load in turbo priority order after the first prompt:

| Priority   | Plugins                                     | File               |
| ---------- | ------------------------------------------- | ------------------ |
| `wait'0'`  | OMZ libs, zsh-vi-mode, FSH, autosuggestions | common-plugins.zsh |
| `wait'0a'` | fzf-tab, mise completions                   | common-plugins.zsh |
| `wait'0b'` | fzf, common-aliases                         | fzf.zsh, aliases   |
| `wait'0c'` | atuin, git-extras                           | atuin.zsh, git.zsh |

### FSH + autosuggestions ordering

FSH must load **before** autosuggestions (per FSH README) so autosuggestions wraps
`accept-line` outermost. Use `atload'!_zsh_autosuggest_start'` (with `!` prefix
for zinit replay tracking).

### Autosuggestion ghost text fixes

Two independent ghost-text bugs exist; each has its own fix.

**Bug 1: rendering artifact on normal accept-line.** `_zsh_autosuggest_clear`
sets `POSTDISPLAY=` but its `zle -R` redraw fires _after_ the inner
`accept-line` commits the line, leaving suggestion text painted in default
foreground on the committed prompt. Fix: `common-plugins.zsh` defines
`_fix_autosuggest_accept_line`, an outer `accept-line` widget that clears
`POSTDISPLAY` + `region_highlight` and calls `zle -R` _before_ delegating to
`zle .accept-line` (the builtin).

**Bug 2: autosuggestion appended to buffer on atuin accept.** When you select
a command from atuin's TUI and press Enter, atuin's widget sets
`LBUFFER=$output` / `RBUFFER=""`, then calls `zle accept-line`. At that point
`POSTDISPLAY` still holds the suggestion text visible before the TUI opened.
Autosuggestions' bound `accept-line` checks
`cursor == #BUFFER && #POSTDISPLAY > 0` (both true) and appends `POSTDISPLAY`
to `BUFFER` — turning `atuin stats --help` into
`atuin stats --help stats --help`. Fix: `post/atuin.zsh` wraps
`atuin-search` and `atuin-search-viins` (the widgets bound to `^R` / vicmd
`/` by `_atuin_rebind_ctrl_r`) with thin wrappers that clear `POSTDISPLAY=`
before delegating to atuin's original functions. By the time atuin invokes
`accept-line`, the suggestion is gone.

#### Why the outer wrapper must be chained into autosuggestions' atload

The Bug 1 wrapper must install _after_ autosuggestions wraps `accept-line`,
otherwise autosuggestions buries it. **Do not** install via a `precmd` hook
or a separate `zinit wait'0*'` block: zinit loads turbo plugins
asynchronously via `zle -F`, so any user wrapper installed by precmd runs
_before_ autosuggestions' atload fires. Autosuggestions then wraps over the
user wrapper, leaving the bound `accept-line` as
`_zsh_autosuggest_bound_1_accept-line` with our wrapper hidden inside.

The only mechanism that works: chain the install into autosuggestions' own
`atload`, after `_zsh_autosuggest_start`:

```zsh
atload'!_zsh_autosuggest_start; _fix_autosuggest_accept_line' zsh-users/zsh-autosuggestions
```

`ZSH_AUTOSUGGEST_MANUAL_REBIND=1` ensures autosuggestions doesn't re-wrap on
later precmds, so the wrapper stays outermost for the life of the shell.

**Wait suffix note:** zinit only accepts `wait'0'`, `wait'0a'`, `wait'0b'`,
`wait'0c'`. `wait'0d'` and beyond emit `Warning: wait ice received invalid
suffix letter` and silently fall back to `wait'0'`.

### Ctrl-R ownership (atuin)

Two plugins try to claim `^R`:

1. **fzf** — `fzf --zsh` binds `^R` to `fzf-history-widget`. Fix: `fzf.zsh`
   caches the fzf init output and strips `bindkey ... '^R'` lines during
   cache generation.
2. **zsh-vi-mode** — binds `^R` to `history-incremental-search-backward`
   when it (re)initialises keymaps (both eager and lazy). Fix: `atuin.zsh`
   hooks `zvm_after_init_commands` and `zvm_after_lazy_keybindings_commands`
   to rebind `^R` to atuin's widgets after every zvm keymap reset.

### `ZSH_AUTOSUGGEST_MANUAL_REBIND=1`

Set in `common-plugins.zsh` to skip O(n) widget re-wrapping on every precmd.
Requires that all widgets needing wrapping exist before `_zsh_autosuggest_start`
runs. History search widgets are registered early in the same file for this reason.

## Key Integrations

| Tool          | Purpose                        |
| ------------- | ------------------------------ |
| zinit         | Plugin manager (turbo loading) |
| mise          | Runtime/tool version manager   |
| fzf           | Fuzzy finder                   |
| zoxide        | Smart directory jumping        |
| powerlevel10k | Prompt theme                   |

## Guidelines

- Keep functions small and focused
- Use autoloaded functions for infrequently-used commands
- Prefer zinit ice modifiers for plugin configuration
- Document environment variables in comments
- Source `~/.zshrc` to test changes

## Standalone Ruby Helpers

Shell helper scripts under `~/.shellrc/zshrc.d/functions/scripts/` may run via plain Ruby
(`ruby`, `mise x ruby -- ruby`, etc.) outside the GitLab application runtime.

- Do not use GitLab app-only Ruby constants or helpers such as `Gitlab::*`
- Prefer stdlib and gem dependencies declared for the helper itself, such as `JSON.parse`
- If a helper consumes external command output, handle parse failures explicitly so shell
  functions can choose whether to fail hard or continue with degraded behavior

## File Permissions

- **Config files** (`configs/`, `configs/pre/`, `configs/post/`): Must be executable (`chmod +x`)
- **Function files** (`functions/`): Should NOT be executable (autoloaded by zsh)
