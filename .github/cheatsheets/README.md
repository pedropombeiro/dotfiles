# Terminal cheat sheets

High-value operations for the terminal tools in these dotfiles. Each sheet skips
the basics and focuses on operations that save navigation, keep context, or
replace several manual steps. Custom bindings come from the tracked
configuration, so the sheets describe this setup rather than upstream defaults.

| Sheet                 | Focus                                                        |
| --------------------- | ------------------------------------------------------------ |
| [tmux](tmux.md)       | Pane surgery, copy mode, command output, tool launchers      |
| [sesh](sesh.md)       | Session sources, project discovery, waiting-agent indicator  |
| [Yazi](yazi.md)       | Git-aware browsing, bulk operations, bookmarks, archives     |
| [Neovim](neovim.md)   | Pickers, LSP refactoring, quickfix, hunks, tests, OpenCode   |
| [LazyGit](lazygit.md) | Line staging, fixups, commit surgery, custom patches         |
| [Atuin](atuin.md)     | Context filters, fuzzy operators, inspector, history cleanup |
| [fzf](fzf.md)         | Shell widgets, fuzzy completion, query syntax                |
| [zoxide](zoxide.md)   | Keyword jumps, interactive selection, integrations           |
| [Zsh](zsh.md)         | Vi-mode editing, history expansion, custom functions         |

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
- Last verified on 2026-10-02 against tmux 3.7c, sesh 2.31.0, Yazi 26.9.1,
  Neovim 0.12.5, LazyGit 0.65.1, Atuin 18.23.0, fzf 0.74.4, zoxide 0.10.0, and
  Zsh 5.9.
