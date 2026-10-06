# Terminal cheat sheets

High-value operations for the terminal tools in these dotfiles. Each sheet skips
the basics and focuses on operations that save navigation, keep context, or
replace several manual steps. Custom bindings come from the tracked
configuration, so the sheets describe this setup rather than upstream defaults.

| Sheet | Focus |
| --- | --- |
| [tmux](tmux.md) | Pane surgery, copy mode, command output, tool launchers |
| [sesh](sesh.md) | Session sources, project discovery, waiting-agent indicator |
| [Yazi](yazi.md) | Git-aware browsing, bulk operations, bookmarks, archives |
| [Neovim](neovim.md) | Pickers, LSP refactoring, quickfix, hunks, tests, OpenCode |
| [LazyGit](lazygit.md) | Line staging, fixups, commit surgery, custom patches |
| [LazyDocker](lazydocker.md) | Container inspection, logs, shells, Compose lifecycle, cleanup |
| [lnav](lnav.md) | Time navigation, log filters, SQL analysis, bookmarks, export |
| [jless](jless.md) | Structural JSON navigation, search, copying values and paths |
| [Atuin](atuin.md) | Context filters, fuzzy operators, inspector, history cleanup |
| [VisiData](visidata.md) | Row subsets, typed columns, aggregations, pivots, joins |
| [fzf](fzf.md) | Shell widgets, fuzzy completion, query syntax |
| [zoxide](zoxide.md) | Keyword jumps, interactive selection, integrations |
| [Zsh](zsh.md) | Vi-mode editing, history expansion, custom functions |

## Open a sheet

| Goal                                           | Command or keys      |
| ---------------------------------------------- | -------------------- |
| Open the sheet for the app in the current pane | `Prefix h`           |
| Open a sheet by name on GitHub                 | `cheat yazi`         |
| Pick a sheet with a preview                    | `cheat`              |
| Read a sheet in the terminal                   | `cheat --local yazi` |
| Open this index                                | `cheat index`        |

`Prefix h` recognizes Neovim, Yazi, LazyGit, LazyDocker, lnav, jless, Atuin,
fzf, sesh, and VisiData when tmux reports `vd` or `visidata`.
The Homebrew VisiData installation on
macOS reports `Python`, so use the picker or `cheat vd` there. In a shell or
another program, it opens the picker in a popup. Over SSH, `cheat` shows the
local file instead of opening a browser. GitHub shows the pushed version of
each sheet, so use `--local` to read edits you haven't pushed yet.

## Key notation

| Notation   | Meaning                                                   |
| ---------- | --------------------------------------------------------- |
| `Prefix`   | The tmux prefix, `Ctrl+B`                                 |
| `<leader>` | The Neovim leader key, `Space`                            |
| `C-x`      | `Ctrl+X`                                                  |
| `M-x`      | `Alt+X` (`Option+X` on macOS, with iTerm2 sending `Esc+`) |
| `g /`      | A key sequence: press `g`, release it, then press `/`     |

## Maintenance

- Regenerate a binding list with `tmux list-keys -N`, `<leader><Tab>` in
  Neovim, `~` in Yazi, or `?` in LazyGit.
- When a configuration file changes a binding, update the matching sheet and
  the private Memos copy tagged `#cheatsheet`.
- VisiData: last verified on 2026-10-06 against version 3.4. Press `z C-h`
  to list commands and bindings for the current sheet.
- LazyDocker, lnav, and jless: last checked on 2026-10-06 against versions
  0.25.2, 0.14.1, and 0.9.0. Use `?` in LazyDocker or lnav, and `F1` in jless
  for built-in help.
- Last verified on 2026-10-02 against tmux 3.7c, sesh 2.31.0, Yazi 26.9.1,
  Neovim 0.12.5, LazyGit 0.65.1, Atuin 18.23.0, fzf 0.74.4, zoxide 0.10.0, and
  Zsh 5.9.
