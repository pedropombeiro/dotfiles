# sesh cheat sheet

Configuration: [`~/.config/sesh/`](../../.config/sesh/). The picker bindings live
in [`tmux.conf`](../../.config/tmux/tmux.conf) and
[`695-common-bindings.zsh`](../../.shellrc/zshrc.d/configs/695-common-bindings.zsh).

## Memorize first

1. `Prefix T` opens the session picker in a tmux popup.
1. `Prefix L`, `fn+Tab`, or `Caps Lock+L` toggles to the previous session.
1. `C-x` inside the picker switches to zoxide directories, so any visited
   project becomes a session in one step.
1. An orange `●` marks a session with an OpenCode agent waiting for input.
1. `M-s` opens the picker from a plain shell outside tmux.

## Picker controls

| Goal                                  | Keys                 | Notes                                    |
| ------------------------------------- | -------------------- | ---------------------------------------- |
| Show all sources                      | `C-a`                | Default view                             |
| Show only running tmux sessions       | `C-t`                |                                          |
| Show configured sessions              | `C-g`                | Dotfiles, Neovim, tmux, mise, and others |
| Show zoxide directories               | `C-x`                | Creates a session on connect             |
| Find directories two levels below `~` | `C-f`                | Uses `fd`, including hidden directories  |
| Kill the highlighted tmux session     | `C-d`                | The list reloads in place                |
| Move through results                  | `Tab` or `Shift+Tab` |                                          |

## Commands

| Goal                                         | Command               |
| -------------------------------------------- | --------------------- |
| Return to the root directory of the session  | `sesh connect --root` |
| Print the root of the current session        | `sesh root`           |
| Clone a repository and open it as a session  | `sesh clone URL`      |
| Create a directory and open it as a session  | `sesh mkdir PATH`     |
| Pick a window from another session           | `sesh window`         |
| Manage Git worktrees as sessions             | `sesh worktree`       |
| Rename a session from its GitHub issue title | `sesh rename`         |
| Inspect raw rows, for scripting              | `sesh list --json`    |

`URL` is a Git remote, and `PATH` is the directory to create.

## Recipes

**Start work on a project you visited last week.** Press `Prefix T`, then `C-x`,
and type part of the directory name. sesh creates the session and runs the
default startup command, `yazi`.

**Edit a tool configuration without leaving your work.** Press `Prefix T`, then
`C-g`, and pick a configured session such as `tmux config`. Return with
`Prefix L`.
