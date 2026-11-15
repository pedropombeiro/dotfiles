# Dotfiles theme selection

`~/.config/dotfiles/theme` is the authoritative theme choice. Available profiles
are `gruvbox`, `tokyonight-night`, and `catppuccin-mocha`.

```sh
dotfiles-theme get
dotfiles-theme list
dotfiles-theme set gruvbox
dotfiles-theme apply --reload

# Install missing upstream assets once, then opt in.
dotfiles-theme install tokyonight-night
dotfiles-theme set tokyonight-night --reload

# Catppuccin Mocha uses blue/cyan prompt and picker accents.
dotfiles-theme install catppuccin-mocha
dotfiles-theme set catppuccin-mocha --reload
```

`set` validates the profile, renders managed settings, and saves the selection.
`apply` regenerates settings after editing a profile or template. Add `--reload`
to either command to reload a running tmux server. Run `theme-refresh` in existing
Zsh shells or start a new shell, and reopen other applications after applying
changes. `install` fetches pinned upstream
assets and rebuilds bat's theme cache. Omit the theme name to install the selected
theme. Applying a theme does not download anything.
OpenCode reloads its theme live without restarting.

For example, switch the theme and refresh the current shell:

```zsh
dotfiles-theme set gruvbox --reload
theme-refresh
```

`theme-refresh` reloads shell exports, rebuilds fzf options, and reloads the
Powerlevel10k prompt. It preserves neither ad hoc edits to `FZF_DEFAULT_OPTS` nor
theme-managed prompt variables. Put persistent fzf customizations in
`.shellrc/rc.d/fzf.sh`.

Application mappings live in `.config/dotfiles/themes/<name>.json`. Native theme
assets and intentional application overrides remain in their owning application
directories. An environment variable is not an alternative theme selector.
Neovim reads the persisted choice directly, including when launched from a GUI.
Other consumers use generated settings, so run `apply` after editing the choice
by hand. Shell startup sources generated exports without starting a process.

## Managed files

### Mise shortcuts

Mise tasks wrap the same CLI and complete theme names from the local profiles:

```zsh
mise theme:list
mise theme:current
mise theme:install catppuccin-mocha
mise theme:set catppuccin-mocha
theme-refresh
mise theme:apply
```

`theme:set` and `theme:apply` reload tmux by default. Pass `--no-reload` to skip
that reload. `theme:install` without a name installs the selected theme's assets.
Mise runs in a child process, so run `theme-refresh` separately in each existing
Zsh shell after setting or applying a theme. Bootstrap continues to use the CLI
directly.

### Configuration ownership

Edit tracked `*.theme` sources for bat, Atuin, btop, lazygit, lnav, Glow, Trippy, and
Yazi. `dotfiles-theme` renders their ordinary configuration paths. It also creates
Git and tmux theme includes, the Glow config, and `dotfiles/theme.json`,
`dotfiles/theme.sh`, and `dotfiles/yazi-theme.lua`. These outputs are ignored by YADM.

btop's tracked template owns defaults. `apply` captures interactive changes in
the ignored `~/.config/btop/local.json` overlay and reapplies them over the latest
defaults. It records the last render to distinguish interactive edits from changes
to tracked defaults. Theme selection always overrides `color_theme`. To reset a
local preference, remove its entry from `local.json`, then run `apply`.
For OpenCode, `apply` updates only
`theme.name` and `theme.mode` in the untracked `opencode/cli.json`, preserving other
preferences. All profiles use native OpenCode themes in dark mode. Avoid setting
`theme` in `cli.base.json` or `OPENCODE_CLI_CONFIG_CONTENT`, which override this file.
Other managed outputs are replaced from their sources, so copy any
application-written changes into the source
before applying again.

The YADM `post_alt` hook runs `apply` after alternate-file maintenance. Theme
failures produce a warning without blocking that maintenance.
Bootstrap installs the selected theme's assets and renders settings before tmux
plugin initialization. The regular bat update step also installs the selected
assets and reapplies settings. Installation records upstream revisions and content
hashes under `~/.config/dotfiles/assets/`. Applying a theme rejects missing,
modified, or outdated runtime assets. Recover with:

```sh
dotfiles-theme install
dotfiles-theme apply
```

The Yazi update step reapplies settings
after refreshing plugins and flavors. Its flavor selection now lives at
`.config/yazi/theme.toml`, outside the downloaded `flavors/` directory.

## Add another theme

Prefer native themes before adding assets. Tokyo Night uses Glow's built-in
`tokyo-night` style and btop's packaged `tokyo-night` theme. bat/delta and Yazi
use pinned assets from `folke/tokyonight.nvim`. Local adapters cover applications
without a built-in Tokyo Night theme. Neovim installs its theme through Lazy.

Catppuccin Mocha uses pinned upstream ports for bat, Yazi, Glow, Atuin, btop, and
the iTerm2 preset. Its `assets.json` lists each repository, revision,
and destination. `install` downloads all assets before writing them. `set` and
`apply` reject missing runtime assets without changing the selection. Local
adapters preserve the tmux, Powerlevel10k, Yatline, lnav, Trippy, VisiData, and
highlight layouts. Lazygit uses the upstream blue palette with local branch
conventions. OpenCode's native theme name is `catppuccin`.

1. Add an application-mapping JSON file under `.config/dotfiles/themes/`.
1. Install the referenced native themes. Add a Neovim plugin specification and
   palette under `nvim/lua/config/themes/`. For tmux, add `<name>/tmux.json`
   semantic colors for the shared `tmux/palette.conf.theme` and
   `tmux/status.conf.theme` layouts. Gruvbox retains its distinct original
   256-color layout under `tmux/themes/`. Preserve the waiting-window and NAS
   indicators.
1. Supply theme-only lazygit and Trippy fragments referenced by the profile.
   Define prompt variables in `<name>/prompt.json`; the renderer clears all
   managed prompt variables before applying the selected palette.
   Set `yatline` to `yatline-local` and add `<name>/yatline.json` colors for the
   shared Yatline adapter. Register any VisiData or lnav themes needed.
1. Run `zsh -df ~/.config/yadm/scripts/tests/test-dotfiles-theme.zsh` and check
   the applications visually before changing the default.
1. Run `zsh -df ~/.config/yadm/scripts/tests/test-tmux-themes.zsh` with tmux and
   `tmux-mode-indicator` installed. It uses a private server to check fresh startup,
   switching both ways, status segments, waiting indicators, and NAS identity.
   CI provisions the pinned mode-indicator dependency and requires this suite
   to run rather than skip.

All tmux palettes use native configuration and share layout settings. No tmux
theme plugin is required. Source the selected theme before TPM initializes the
mode indicator, and apply host-specific status overrides afterward.

## iTerm2 Dynamic Profiles

On macOS, `set` and `apply` generate
`~/Library/Application Support/iTerm2/DynamicProfiles/dotfiles-theme.json`.
iTerm2 watches this directory and loads the profiles without a restart. The
generated file is ignored by YADM. Bootstrap and regular theme updates populate
it through the same installer and renderer.

`~/.config/iterm2/dynamic-profiles.json` defines stable child GUIDs, names, and
parent GUIDs. Generated profiles use clean everyday names such as `Default` and
`GDK rails console`. Keep the original parent profiles with a `· base` suffix
to distinguish the editable bases from their generated children. Inheritance uses
GUIDs, so renaming a parent does not break it.
The GDK, Rails console, development logs, Postgres console, Postgres thin clone
(CI and main), and ClickHouse client
children inherit from their respective parents when present, so the same mapping
works on Work and Personal machines. Profiles outside this mapping remain unchanged. Missing
required parents and GUID collisions stop rendering before any output is written.

The generated children override colors and disable separate light/dark palettes
so the selected dark theme applies regardless of macOS appearance. Commands,
fonts, key bindings, and layout preferences inherit from the parents. Edit those
preferences in the parent profile, not in the generated child. Theme switching
does not edit the application-owned Work/Personal preferences plist.

### Start using the themed profiles

1. Run `dotfiles-theme install`, then `dotfiles-theme apply`.
1. Rename the original parent profiles with a `· base` suffix in iTerm2. Keep
   their GUIDs unchanged. Do this before using the generated profiles so profile
   names are unambiguous. Apply the same naming on each Mac.
1. Open iTerm2 **Settings > Profiles** and select the generated `Default`.
1. Use **Other Actions > Set as Default** if new windows should use it.
1. Open a session with `Default` or `GDK`. Update shortcuts
   or automation that explicitly selects the original profiles when appropriate.

Existing sessions using the original profiles do not migrate automatically.
`mise iterm:setup` applies the selected theme and opens themed children for every
profile in its workspace, including the development logs split. It reuses existing
themed tabs and splits. On the first run after migration, original-profile tabs
remain open and separate themed tabs are created. Close the old tabs when ready.
Test switching in a themed session before relying on live updates. If a session
has local color overrides, reopen it with the themed profile. Profile identities
stay fixed across switches. No Python API, background watcher, or manual color
preset import is required. WakaTime's CLI theme remains outside the selector.

Run `zsh -df ~/.config/yadm/scripts/tests/test-iterm2-themes.zsh` for isolated
renderer tests. The test does not launch iTerm2 or modify real preferences.
