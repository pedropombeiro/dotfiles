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
| Start a selection, or select whole lines | `v` or `Space`, or `V`         |
| Start a rectangular selection            | `C-v`                          |
| Switch between rectangular and normal    | `C-v` (or `v` to go back)      |
| Cancel the selection                     | `v` on a normal selection      |
| Copy to the system clipboard and exit    | `Enter`                        |
| Copy from the cursor to the end of line  | `D`                            |
| Append the selection to the last buffer  | `A`                            |
| Jump to a line number                    | `:`                            |
| Pick an older paste buffer               | `Prefix =` (outside copy mode) |

Mouse drags keep the selection instead of copying immediately. Press `Enter`
to copy it.

## Hint copy

`Prefix F` starts tmux-fingers, which labels copyable text in the pane with
hints. Type a hint to copy its match without entering copy mode.

| Goal                                      | Keys                 | Notes                                  |
| ----------------------------------------- | -------------------- | -------------------------------------- |
| Copy a match                              | The hint letters     | Shows a "copied" message               |
| Copy a match and paste it into the pane   | `Shift` + hint       |                                        |
| Copy a match and open it                  | `Ctrl` + hint        | URLs in the browser, files in Finder   |
| Copy several matches at once              | `Tab`, hints, `Tab`  | The second `Tab` copies the selection  |
| Leave without copying                     | `q`, `Esc`, or `C-c` |                                        |

It highlights SHAs, URLs, paths, IPs, UUIDs, hex values, numbers with four or
more digits, and paths in `git status` and diff output. Custom patterns add
GitLab references such as `!12345` or `gitlab-org/gitlab#678`, and `file:line`
locations from RSpec, RuboCop, and grep output.

## Custom launchers

| Goal                                     | Keys                     | Notes                                         |
| ---------------------------------------- | ------------------------ | --------------------------------------------- |
| Copy the previous command's output       | `Prefix y`               | Uses OSC 133 prompt markers                   |
| Copy the command line you are typing     | `Prefix Y`               | Works without copy mode                       |
| Copy a SHA, URL, path, or MR on screen   | `Prefix F`, then a hint  | See [Hint copy](#hint-copy)                   |
| Open LazyGit in a zoomed pane            | `Prefix l`               | Uses YADM in `~` and `~/.config`              |
| Open Yazi through `fm` in a zoomed pane  | `Prefix f`               | Starts in the pane's directory                |
| Start or resume OpenCode in a side pane  | `Prefix o` or `Prefix O` |                                               |
| Open the sesh picker or the last session | `Prefix T` or `Prefix L` | See the [sesh sheet](sesh.md)                 |
| Open the cheat sheet for the pane's app  | `Prefix h`               | Picker for shells; see the [index](README.md) |

## Recipes

**Send a failing command's output to a chat or an agent.** Run the command,
press `Prefix y`, and paste. The binding selects the region between the last two
prompts, so it works even after the output scrolls away.

**Grab one value from noisy output.** Press `Prefix F` and type the hint next to
the SHA, URL, IP, MR reference such as `!12345`, or `file:line` from RSpec or
RuboCop output. `Tab` selects several matches before copying. Over SSH to the
NAS, the copy reaches the Mac clipboard through OSC 52.

**Reshape a cluttered window.** Press `Prefix m` on a pane you want elsewhere,
switch to the target window, run `Prefix :` then `join-pane -h`. Press
`Prefix !` to send a pane the other way, into a new window.

**Find the agent that needs you.** Windows waiting for OpenCode input show an
orange bullet. Press `Prefix M-n` to cycle through them, or `Caps Lock+A` to jump
across sessions through Hammerspoon.
