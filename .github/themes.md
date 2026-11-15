# Dotfiles theme selection

`~/.config/dotfiles/theme` is the authoritative theme choice. It currently contains
`gruvbox`. `tokyonight-night` is available as an opt-in alternative.

```sh
dotfiles-theme get
dotfiles-theme list
dotfiles-theme set gruvbox
dotfiles-theme apply --reload

# Install missing upstream assets once, then opt in.
dotfiles-theme install tokyonight-night
dotfiles-theme set tokyonight-night --reload
```

`set` validates the profile, renders managed settings, and saves the selection.
`apply` regenerates settings after editing a profile or template. Add `--reload`
to either command to reload a running tmux server. Run `theme-refresh` in existing
Zsh shells or start a new shell, and reopen other applications after applying
changes. `install` fetches pinned upstream
assets and rebuilds bat's theme cache. Applying a theme does not download anything.
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

Edit tracked `*.theme` sources for bat, Atuin, btop, lazygit, lnav, Glow, Trippy, and
Yazi. `dotfiles-theme` renders their ordinary configuration paths. It also creates
Git and tmux theme includes, the Glow config, and `dotfiles/theme.json`,
`dotfiles/theme.sh`, and `dotfiles/yazi-theme.lua`. These outputs are ignored by YADM.

btop writes interactive preferences to its config. After the initial render,
`apply` changes only its `color_theme` setting. For OpenCode, `apply` updates only
`theme.name` and `theme.mode` in the untracked `opencode/cli.json`, preserving other
preferences. Both profiles use native OpenCode themes in dark mode. Avoid setting
`theme` in `cli.base.json` or `OPENCODE_CLI_CONFIG_CONTENT`, which override this file.
Other managed outputs are replaced from their sources, so copy any
application-written changes into the source
before applying again.

The YADM `post_alt` hook runs `apply` after alternate-file maintenance. Theme
failures produce a warning without blocking that maintenance.
The Yazi update step reapplies settings
after refreshing plugins and flavors. Its flavor selection now lives at
`.config/yazi/theme.toml`, outside the downloaded `flavors/` directory.

## Add another theme

Prefer native themes before adding assets. Tokyo Night uses Glow's built-in
`tokyo-night` style and btop's packaged `tokyo-night` theme. bat/delta and Yazi
use pinned assets from `folke/tokyonight.nvim`. Local adapters cover applications
without a built-in Tokyo Night theme. Neovim installs its theme through Lazy.

1. Add an application-mapping JSON file under `.config/dotfiles/themes/`.
1. Install the referenced native themes. Add a Neovim plugin specification and
   palette under `nvim/lua/config/themes/`, and tmux theme/status includes under
   `tmux/themes/`. Preserve the waiting-window and NAS indicators.
1. Supply theme-only lazygit and Trippy fragments referenced by the profile.
   Define prompt variables in `<name>/prompt.json`; the renderer clears all
   managed prompt variables before applying the selected palette.
   Adapt custom Yatline colors and register any VisiData or lnav themes needed.
1. Run `zsh -df ~/.config/yadm/scripts/tests/test-dotfiles-theme.zsh` and check
   the applications visually before changing the default.
1. Run `zsh -df ~/.config/yadm/scripts/tests/test-tmux-themes.zsh` with tmux and
   `tmux-mode-indicator` installed. It uses a private server to check fresh startup,
   switching both ways, status segments, waiting indicators, and NAS identity.

Both tmux palettes use native configuration and share layout settings. No tmux
theme plugin is required. Source the selected theme before TPM initializes the
mode indicator, and apply host-specific status overrides afterward.

iTerm2 profile colors and the WakaTime CLI theme are not applied by this command.
iTerm2 preferences remain application-owned Work/Personal alternates. The profile's
`iterm` mapping records the intended preset for a later integration. Applying
terminal colors needs separate handling to preserve profile identities and live
preferences. `install` downloads an iTerm2 color preset under
`~/.config/iterm2/themes/` for manual import without modifying profiles.
