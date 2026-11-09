# Tail the latest temp file

Press `<leader>o` (`Ctrl+X`, then `o` by default) to toggle a tmux pane below
OpenCode. The pane takes 30% of the OpenCode pane's height and runs `tail -F`
on the most recently modified regular file under `$TMPDIR/opencode`, including
subdirectories. If `TMPDIR` is unset, the plugin uses the system temp directory.
Symlinks are skipped.

Focus stays in OpenCode. Press the shortcut again to close the tail pane, then
again to select the latest file. The running tail does not switch automatically
when a newer file appears. Files are selected globally, not by session.
The last 10 lines appear initially, followed by appended content. `tail -F`
continues following the path if the file is replaced.

When `bat` is installed, the output uses syntax highlighting based on the
filename, with no pager or decorations. Files with unknown extensions stay
plain. If `bat` is unavailable, the pane runs plain `tail -F`.

Each OpenCode pane owns its own tail pane, marked with `@opencode-tail` in tmux.
The toggle survives plugin reloads. You can also focus the tail pane and press
`Ctrl+C` to close it. Outside tmux, or when there are no files, the command shows
a warning without opening a pane.

The command is also available as **Toggle latest temp-file tail** in the
command palette. Both `cli.base.json` alternates load the plugin. After changing
the plugin list, launch OpenCode from a new shell to refresh
`OPENCODE_CLI_CONFIG_CONTENT`.

## Tests

From this directory, run:

```sh
mise exec bun@1.3.10 -- bun test
```
