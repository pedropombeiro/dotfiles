# tmux cheat sheet

Configuration: [`~/.config/tmux/tmux.conf`](../../.config/tmux/tmux.conf).
`Prefix` is `Ctrl+B`.

## Memorize first

1. `Prefix y` copies the previous command's output to the clipboard.
1. `M-h` `M-j` `M-k` `M-l` move between tmux panes and Neovim splits.
1. `Prefix z` zooms a pane, and `Prefix !` breaks it out into its own window.
1. `Prefix M-n` jumps to the next window with an alert, such as an OpenCode
   agent waiting for input.
1. `Prefix Space` opens the which-key menu when you forget a binding, and
   `Prefix h` opens the cheat sheet for the app in the pane.

## Panes and windows

| Goal                                    | Keys or command               | Notes                           |
| --------------------------------------- | ----------------------------- | ------------------------------- |
| Split beside or below, keeping the path | `Prefix \|` or `Prefix -`     | `"` and `%` also keep the path  |
| Split across the full width or height   | `Prefix \` or `Prefix _`      |                                 |
| Open a floating pane                    | `Prefix *`                    | tmux 3.7                        |
| Jump to window 1 to 9, or the last one  | `M-1` to `M-9`, `M-0`         | No prefix                       |
| Reorder windows                         | `Prefix <` or `Prefix >`      | Or drag a tab with the mouse    |
| Swap the active pane with a neighbor    | `Prefix {` or `Prefix }`      |                                 |
| Jump to a pane by number                | `Prefix q`, then the digit    |                                 |
| Return to the previous pane             | `M-^` or `Prefix ;`           |                                 |
| Resize in steps of five cells           | `Prefix H` `J` `K`            | `Prefix M-Right` resizes right  |
| Apply a preset layout                   | `Prefix M-1` to `Prefix M-7`  | `Prefix E` spreads panes evenly |
| Move a pane into another window         | `Prefix m`, then `:join-pane` | Joins the marked pane           |
| Kill a pane without confirmation        | `Prefix x`                    |                                 |
| Reload the configuration                | `Prefix r`                    |                                 |

## Copy mode

Enter with `Prefix [`. Bindings follow vi.

| Goal                                     | Keys                           |
| ---------------------------------------- | ------------------------------ |
| Search forward or backward               | `/` or `?`, then `n` and `N`   |
| Start a selection, or select whole lines | `Space` or `V`                 |
| Toggle a rectangular selection           | `v` or `C-v`                   |
| Copy to the system clipboard and exit    | `Enter`                        |
| Copy from the cursor to the end of line  | `D`                            |
| Append the selection to the last buffer  | `A`                            |
| Jump to a line number                    | `:`                            |
| Pick an older paste buffer               | `Prefix =` (outside copy mode) |

Mouse drags keep the selection instead of copying immediately. Press `Enter`
to copy it.

## Custom launchers

| Goal                                     | Keys                     | Notes                                         |
| ---------------------------------------- | ------------------------ | --------------------------------------------- |
| Copy the previous command's output       | `Prefix y`               | Uses OSC 133 prompt markers                   |
| Copy the command line you are typing     | `Prefix Y`               | Works without copy mode                       |
| Open LazyGit in a zoomed pane            | `Prefix l`               | Uses YADM in `~` and `~/.config`              |
| Open Yazi through `fm` in a zoomed pane  | `Prefix f`               | Starts in the pane's directory                |
| Start or resume OpenCode in a side pane  | `Prefix o` or `Prefix O` |                                               |
| Open the sesh picker or the last session | `Prefix T` or `Prefix L` | See the [sesh sheet](sesh.md)                 |
| Open the cheat sheet for the pane's app  | `Prefix h`               | Picker for shells; see the [index](README.md) |

## Recipes

**Send a failing command's output to a chat or an agent.** Run the command,
press `Prefix y`, and paste. The binding selects the region between the last two
prompts, so it works even after the output scrolls away.

**Reshape a cluttered window.** Press `Prefix m` on a pane you want elsewhere,
switch to the target window, run `Prefix :` then `join-pane -h`. Press
`Prefix !` to send a pane the other way, into a new window.

**Find the agent that needs you.** Windows waiting for OpenCode input show an
orange bullet. Press `Prefix M-n` to cycle through them, or `Caps Lock+A` to jump
across sessions through Hammerspoon.
