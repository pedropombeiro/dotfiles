# Dotfiles theme selection

`~/.config/dotfiles/theme` is the authoritative theme choice. It currently contains
`gruvbox`. Tokyo Night is not installed yet.

```sh
dotfiles-theme get
dotfiles-theme list
dotfiles-theme set gruvbox
dotfiles-theme apply --reload
```

`set` validates the profile, renders managed settings, and saves the selection.
`apply` regenerates settings after editing a profile or template. Add `--reload`
to either command to reload a running tmux server. Start a new shell and reopen
other applications after applying changes. The command does not install themes
or rebuild bat's theme cache.

Application mappings live in `.config/dotfiles/themes/<name>.json`. Native theme
assets and intentional application overrides remain in their owning application
directories. An environment variable is not an alternative theme selector.
Neovim reads the persisted choice directly, including when launched from a GUI.
Other consumers use generated settings, so run `apply` after editing the choice
by hand. Shell startup sources generated exports without starting a process.

## Managed files

Edit tracked `*.theme` sources for bat, Atuin, btop, lazygit, lnav, Trippy, and
Yazi. `dotfiles-theme` renders their ordinary configuration paths. It also creates
Git and tmux theme includes, the selected Glow style, and `dotfiles/theme.json`,
`dotfiles/theme.sh`, and `dotfiles/yazi-theme.lua`. These outputs are ignored by YADM.

btop writes interactive preferences to its config. After the initial render,
`apply` changes only its `color_theme` setting. Other managed outputs are replaced
from their sources, so copy any application-written changes into the source
before applying again.

The YADM `post_alt` hook runs `apply`. The Yazi update step reapplies settings
after refreshing plugins and flavors. Its flavor selection now lives at
`.config/yazi/theme.toml`, outside the downloaded `flavors/` directory.

## Add another theme

1. Add an application-mapping JSON file under `.config/dotfiles/themes/`.
1. Install the referenced native themes. Add a Neovim plugin specification and
   palette under `nvim/lua/config/themes/`, and tmux theme/status includes under
   `tmux/themes/`. Preserve the waiting-window and NAS indicators.
1. Supply theme-only lazygit and Trippy fragments referenced by the profile.
   Adapt custom Yatline colors and register any VisiData or lnav themes needed.
1. Run `zsh -df ~/.config/yadm/scripts/tests/test-dotfiles-theme.zsh` and check
   the applications visually before changing the default.

iTerm2 profile colors and the WakaTime CLI theme are not applied by this command.
iTerm2 preferences remain application-owned Work/Personal alternates. The profile's
`iterm` mapping records the intended preset for a later integration. Applying
terminal colors needs separate handling to preserve profile identities and live
preferences.
