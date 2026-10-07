# Shell Configuration

Zsh configuration with modular structure and zinit plugins.

## Structure

```text
~/.shellrc/
├── zshrc.d/
│   ├── configs/          # Numbered startup phases, loaded in filename order
│   └── functions/        # Autoloaded shell functions
└── rc.d/                 # Shared bash/zsh configs
```

## Key Files

- `~/.zshenv` - Environment variables for all zsh sessions (loads earliest)
- `~/.zshrc.shared` - Main zsh entry point
- `~/.shellrc/zshrc.d/configs/350-zinit.zsh` - Plugin manager and completion setup
- `~/.shellrc/zshrc.d/configs/410-mise.zsh` - Tool environment activation
- `~/.shellrc/zshrc.d/configs/695-common-bindings.zsh` - Shared key mappings

## Loading Order

`~/.zshenv` loads first. `~/.zshrc.shared` then loads executable files matching
`configs/[0-9][0-9][0-9]-*.*sh` in filename order. Reserve these ranges:

| Range     | Phase                                | Examples                                                         |
| --------- | ------------------------------------ | ---------------------------------------------------------------- |
| `000–099` | Early bootstrap                      | Homebrew discovery, grc preload, instant prompt                  |
| `100–199` | Platform environment and paths       | Entware, Rust, mise architecture, GDK environment, path ordering |
| `200–299` | Startup directory                    | NAS directory selection                                          |
| `300–399` | Completion infrastructure            | Site-functions, generators, cache checks, zinit, `compinit`      |
| `400–499` | Tool environment activation          | Mise                                                             |
| `500–599` | Integrations and plugin registration | Deferred-init helper, zoxide, Git, tmux, vi-mode, Atuin, fzf     |
| `600–699` | Interactive configuration            | Aliases, history, terminal integration, prompt, keybindings      |
| `700–999` | Reserved                             | Future phases                                                    |

Use three digits and leave gaps for additions. Keep all startup files directly in
`configs/`; subdirectories do not participate in loading. Unnumbered files such as
`tmux.platform.zsh` are explicit includes. Preserve YADM suffixes when renaming files.

Finish startup directory, `PATH`, and mise-setting changes before phase 400.
Homebrew discovery stays in phase 000 because grc needs its prefix before instant
prompt redirects the terminal. Completion setup must precede mise activation.
Phase 500 registers deferred plugins; zinit's `wait` priorities still control
their execution after the first prompt.

After the numbered phases, the loader replays completion definitions, loads shared
`rc.d/` snippets, and registers autoloaded functions. Shared platform path snippets
also run in phase 100 so their later invocation leaves `PATH` unchanged.

## PATH Ordering (macOS)

macOS `path_helper` (via `/etc/zprofile`) can push Homebrew and mise paths
behind `/usr/bin`. `190-path-ordering.zsh` restores the intended
priority so completion scripts (like Homebrew's `_git`) match the selected
binary:

`mise installs` > `mise shims` > `~/.local/bin` > `Homebrew` > `system`

### Completion and mise startup order

`190-path-ordering.zsh` sets the base path. Completion generation (`320` and
`330`) and dump invalidation (`340`) run before `350-zinit.zsh` adds zinit's
completion directories and initializes `compinit` once. `410-mise.zsh` then runs
`mise activate zsh`, including its initial environment hook, so concrete tool
paths are ready for the first command.

Before activation, remove inherited paths under mise's installation directory
and capture the remaining path as `__MISE_ORIG_PATH`. This lets mise select and
order concrete installs in nested shells and tmux panes without dropping other
inherited paths.

Keep mise activation after `compinit`: mise's version-specific tool completions
can otherwise trigger another initialization. Generate activation for each shell
because its output embeds the current `PATH`. Preserve its `precmd` and `chpwd`
hooks for project environment changes. Completion generators publish non-empty,
successful output atomically and retain the previous file on failure.

On QTS, load Entware and the Docker/yadm paths in `110-entware-profile.sh`,
Rust paths in `120-rust-path.zsh`, and `MISE_INSTALL_ARCH` in `130-mise-arch.zsh`, before
path ordering and mise activation. `210-nas-startup.zsh` selects the NAS startup
directory before activation. Later changes to `PATH` or `MISE_*` variables make
mise check the environment again at the first prompt. Keep platform path setup
before activation so fresh and nested shells can use mise's first-prompt fast path.

## XDG Base Directories

`~/.zshenv` exports `XDG_CONFIG_HOME=~/.config` so that macOS CLI tools using
Go XDG libraries (`adrg/xdg`, `OpenPeeDeeP/xdg`) resolve config to `~/.config/`
instead of `~/Library/Application Support/`. This allows dotfile tracking via yadm.

Tools unaffected (use Rust `dirs` crate, ignores XDG on macOS): rtk, zoxide, neovide (settings).

`.shellrc/rc.d/_xdg.sh` sets the same default for bash. Prefer a tool's
`~/.config` location over a file at the repository root. If a tool needs an
environment variable to find it, export the variable from `.shellrc/rc.d/`, as
`highlight.sh` does with `HIGHLIGHT_DATADIR`. GUI launchers such as Raycast
don't load these files, so pass an explicit config path in their scripts.

## Alternate Files

Use platform-specific suffixes. See [YADM Layout](yadm-layout.md#machine-identity)
for the conditions.

## Adding Functions

Create files in `~/.shellrc/zshrc.d/functions/`:

- One function per file
- Filename = function name
- No file extension needed
- Functions are autoloaded on first use

### Context-Aware Bundler Helper

The `be` function runs `bundle exec` in ordinary repositories. In a GitLab
checkout nested below a Caproni environment, it runs
`.gitlab/caproni/exec.sh bundle exec` instead so development commands use the
cluster toolbox context through the Caproni execution wrapper.

## Plugin Load Order (zinit turbo)

Plugins load in turbo priority order after the first prompt:

| Priority               | Plugins                                                                        | Files                                                                    |
| ---------------------- | ------------------------------------------------------------------------------ | ------------------------------------------------------------------------ |
| `wait'0'` / `wait'0a'` | zoxide, OMZ libs, FSH, autosuggestions, fzf-tab, CLI completions, Git, vi-mode | 505-zoxide.zsh, 510-common-plugins.zsh, 520-git.zsh, 570-zsh-vi-mode.zsh |
| `wait'0b'`             | fzf, OpenCode completion, common-aliases                                       | 591-fzf.zsh, 594-opencode.zsh, 610-common-aliases.zsh                    |
| `wait'0c'`             | git-extras, Atuin                                                              | 520-git.zsh, 590-atuin.zsh                                               |

`wait'0'` and `wait'0a'` share the first priority group, in submission order.
`500-deferred-init.zsh` defines `_defer_shell_init`, which registers named
local tasks such as `shell/atuin` and `shell/fzf`. Small OMZ libraries and
the Git library/plugin share scheduler turns within their
respective groups. Nested snippets still use zinit's normal tracking.

Use `zinit times` for load durations and `zinit times -m` for load completion
moments relative to zinit's first prompt hook. Run these in a fresh interactive
shell after turbo tasks finish. Group timings include nested snippet timings,
so the printed total double-counts those snippets. Compare final loading moments
and individual tasks rather than totals when evaluating grouped loads. The
installed zinit rejects `times -a`; use the two commands separately.

Zoxide's default initialization is cached at
`${XDG_CACHE_HOME:-$HOME/.cache}/zoxide/init.zsh`. The cache tracks the executable
path and the executable/configuration timestamps, and is written atomically.
When `_ZO_*` customization variables are set, generate initialization for that
shell instead. Keep Atuin's session ID generation per-session.

### FSH + autosuggestions ordering

FSH must load **before** autosuggestions (per FSH README) so autosuggestions wraps
`accept-line` outermost. Use `atload'!_zsh_autosuggest_start'` (with `!` prefix
for zinit replay tracking).

### Autosuggestion ghost text fixes

Two wrappers keep autosuggestion ghost text out of committed commands:

- **Normal accept-line.** `_zsh_autosuggest_clear` redraws after the inner
  `accept-line` commits the line, which leaves suggestion text on the committed
  prompt. `_fix_autosuggest_accept_line` in `510-common-plugins.zsh` installs an
  outer `accept-line` that clears `POSTDISPLAY` and `region_highlight` and runs
  `zle -R` before `zle .accept-line`.
- **Atuin accept.** Atuin's widget sets the buffer and calls `zle accept-line`
  while `POSTDISPLAY` still holds the old suggestion, so autosuggestions appends
  it to the command. `590-atuin.zsh` wraps `atuin-search` and
  `atuin-search-viins` to clear `POSTDISPLAY` first.

#### Chain the accept-line wrapper into autosuggestions' atload

The accept-line wrapper must install _after_ autosuggestions wraps
`accept-line`, otherwise autosuggestions buries it. Don't install it from a
`precmd` hook or a separate `zinit wait'0*'` block: zinit loads turbo plugins
asynchronously via `zle -F`, so those run before autosuggestions' atload.
Chain the install into autosuggestions' own `atload`, after
`_zsh_autosuggest_start`:

```zsh
atload'!_zsh_autosuggest_start; _fix_autosuggest_accept_line' zsh-users/zsh-autosuggestions
```

`ZSH_AUTOSUGGEST_MANUAL_REBIND=1` ensures autosuggestions doesn't re-wrap on
later precmds, so the wrapper stays outermost for the life of the shell.
All widgets needing wrapping must exist before `_zsh_autosuggest_start` runs.
History search widgets are registered early in `510-common-plugins.zsh` for this reason.

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

The same hook binds the Up and Down arrows to prefix search. Always pass
`-M KEYMAP` to `bindkey` in startup scripts. zsh-vi-mode loads deferred, so an
unqualified `bindkey` lands in `emacs`, which is `main` at that point, and never
reaches `viins`. Bind `viins` and `vicmd` explicitly, and use the zvm hooks for
keys that zsh-vi-mode overrides. Use zsh-vi-mode's `vv` to edit the command line
in `$EDITOR` instead of rebinding `v`, which zsh-vi-mode reclaims for visual
mode on the first switch to normal mode.

#### Cached init recovery

`590-atuin.zsh` caches `atuin init zsh --disable-up-arrow` at
`$XDG_DATA_HOME/atuin/init.zsh` (normally `~/.local/share/atuin/init.zsh`). A
failed shell-out can otherwise truncate that cache, leaving `^R` bound to a
wrapper that calls an undefined `_atuin_search`. Generate into a temporary
file and move it into place only when the command succeeds with non-empty
output. The cache test must use `-s`, not `-f`, so a previously corrupt empty
file is rebuilt automatically.

If an older configuration leaves an empty cache behind, remove it and start a
new shell:

```zsh
rm ~/.local/share/atuin/init.zsh
```

## History exclusions

Native history and Atuin exclude `op://`, encoded `/1PE` references, and configured
`export` patterns containing `TOKEN`, `SECRET`, or `PASSWORD`. The native
`zshaddhistory` hook prevents persistence and discards rejected entries after the
next command. `HISTORY_IGNORE` also filters explicit history-file writes.
Atuin retains its additional built-in secret filtering.

Keep `SHARE_HISTORY` for cross-pane history. It already appends commands, so
`INC_APPEND_HISTORY` is disabled. Verify the policy independently of shell
startup with `zsh -df ~/.config/yadm/scripts/check-shell-history.zsh`.

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
- Test changes in a new shell; re-sourcing does not undo earlier definitions

## Standalone Ruby Helpers

Shell helper scripts under `~/.shellrc/zshrc.d/functions/scripts/` may run via plain Ruby
(`ruby`, `mise x ruby -- ruby`, etc.) outside the GitLab application runtime.

- Do not use GitLab app-only Ruby constants or helpers such as `Gitlab::*`
- Prefer stdlib and gem dependencies declared for the helper itself, such as `JSON.parse`
- If a helper consumes external command output, handle parse failures explicitly so shell
  functions can choose whether to fail hard or continue with degraded behavior

## File Permissions

- **Numbered config files** (`configs/`): Must be executable (`chmod +x`). Explicit includes such as `tmux.platform.zsh`
  do not need the executable bit.
- **Function files** (`functions/`): Should NOT be executable (autoloaded by zsh)
