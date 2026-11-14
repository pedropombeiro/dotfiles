# btop cheat sheet

Configuration: [`~/.config/btop/btop.conf`](../../.config/btop/btop.conf).
This setup enables Vim-style keys, so `h` and `l` change the process sort
column, `j` and `k` move the selection, and `H` opens help. Open this sheet
with `cheat btop` or `Prefix h` in tmux.

## Memorize first

1. `/` filters processes. Press `Enter` to keep the filter or `Esc` to cancel.
1. `h` and `l` cycle sort columns. `r` reverses the order.
1. `Enter` opens process details. `F` follows the selected process.
1. `e` switches to a process tree. `Space` collapses or expands a branch.
1. `t` offers SIGTERM for the selected process. `K` offers SIGKILL, not `k`.

## How this setup behaves

- The theme is Gruvbox Dark, with CPU, memory, network, and process boxes shown.
- Updates run every two seconds. Processes start sorted by **cpu lazy**, which
  favors sustained CPU use over momentary spikes. Choose **cpu direct** to
  sort by the current sample instead.
- Process CPU percentages start relative to total CPU capacity. Press `c`
  to switch to per-core usage when comparing single-threaded workloads.
- Process memory starts in bytes. Press `%` to switch to percentages.
- Opening process details automatically follows that process. Press `F` to
  toggle following without closing the details view.
- Tree view starts disabled, and child resources aren't always accumulated
  into their parent. Check `proc_aggregate` in options before treating a
  parent's figures as the whole application's usage.
- Settings save on exit. Layout and sorting changes can modify the tracked
  configuration, so check `yadm diff -- .config/btop/btop.conf` afterward.

## Find and inspect processes

| Goal | Keys | Notes |
| --- | --- | --- |
| Filter processes | `/` or `f` | Start the filter with `!` for a regular expression |
| Apply or cancel a filter edit | `Enter` or `Esc` | `Esc` restores the previous filter |
| Clear the filter | `Delete` | Outside the filter editor |
| Select a process | `j` or `k` | Arrow keys also work |
| Jump through the list | `PageUp`, `PageDown`, `g`, `G` | `g` and `G` jump to the first and last pages |
| Change the sort column | `h` or `l` | Left and Right also work |
| Reverse the sort order | `r` | |
| Open or close process details | `Enter` | Select a process first |
| Follow a process as its rank changes | `F` | Press again on the followed process to stop |
| Pause or resume the process list | `u` | Doesn't suspend the processes themselves |
| Toggle the process tree | `e` | |
| Collapse or expand a branch | `Space` | In tree view, with a process selected |
| Collapse or expand all branches | `E` | Tree view only |
| Switch total-capacity or per-core CPU usage | `c` | Changes process CPU percentages |
| Switch memory bytes or percentages | `%` | Process list only |

## Change the view

| Goal | Keys | Notes |
| --- | --- | --- |
| Cycle layout presets | `p` or `P` | Forward or backward |
| Toggle CPU, memory, network, or process boxes | `1`, `2`, `3`, `4` | Each key toggles one box |
| Toggle disks in the memory box | `d` | |
| Switch disks to I/O graphs | `i` | Compare read and write activity |
| Change the network interface | `b` or `n` | Previous or next interface |
| Toggle automatic network scaling | `a` | Enabled initially |
| Toggle shared upload/download scaling | `y` | Enabled initially to keep the graph scales comparable |
| Open options | `o` or `F2` | Includes theme, sensors, and process settings |
| Open help | `H`, `?`, or `F1` | Lowercase `h` changes sorting in this setup |
| Reload the configuration from disk | `C-r` | |
| Quit | `q` | Saves current settings |

## Send signals safely

Select a process and verify its PID, user, and command in the details view
before sending a signal. Each action opens a signal dialog for confirmation.

| Goal | Keys | Notes |
| --- | --- | --- |
| Request a graceful shutdown | `t` | SIGTERM, signal 15 |
| Force termination | `K` | SIGKILL, signal 9. The process can't clean up |
| Choose another signal | `s` | Select or enter the signal in the dialog |

Prefer SIGTERM first. Use SIGKILL only when necessary, and avoid launching
btop with elevated privileges just to inspect ordinary processes.

## Recipes

**Find a sustained CPU consumer.** Clear any filter, use `h` or `l` to choose
**cpu lazy**, and select the busy process with `j` or `k`. Press `Enter` for
details, which also follows it while its rank changes. Use `c` if you need to
interpret its usage relative to one core.

**Inspect a multi-process application.** Filter by the application's name,
press `Enter`, then `e` for tree view. Expand the relevant branch with `Space`.
Check individual children and the aggregation setting before comparing totals.

Checked on 2026-11-14 against btop 1.4.8, the tracked configuration, and the
versioned [help reference](https://github.com/aristocratos/btop/blob/v1.4.8/src/btop_menu.cpp#L174-L221)
and [input handling](https://github.com/aristocratos/btop/blob/v1.4.8/src/btop_input.cpp).
