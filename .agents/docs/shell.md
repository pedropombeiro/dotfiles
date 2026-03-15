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
| `wait'0d'` | accept-line ghost text fix                  | common-plugins.zsh |

### FSH + autosuggestions ordering

FSH must load **before** autosuggestions (per FSH README) so autosuggestions wraps
`accept-line` outermost. Use `atload'!_zsh_autosuggest_start'` (with `!` prefix
for zinit replay tracking).

### Autosuggestion ghost text fix

Even with correct load order, `_zsh_autosuggest_clear` sets `POSTDISPLAY=` but
its `zle -R` runs **after** the inner `accept-line` commits the line, leaving
ghost text painted in default foreground. The `wait'0d'` block in
`common-plugins.zsh` installs an outermost `accept-line` wrapper that clears
`POSTDISPLAY` + `region_highlight` and calls `zle -R` **before** `zle .accept-line`.

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

## File Permissions

- **Config files** (`configs/`, `configs/pre/`, `configs/post/`): Must be executable (`chmod +x`)
- **Function files** (`functions/`): Should NOT be executable (autoloaded by zsh)
