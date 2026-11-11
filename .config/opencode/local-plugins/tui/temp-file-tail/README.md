# Temp-file tail

Press `<leader>o` (`Ctrl+X`, then `o` by default) to toggle a tmux pane below
OpenCode. The pane takes 30% of the OpenCode pane's height and runs `tail -F`
on the most recently modified regular file under `$TMPDIR/opencode`, including
subdirectories. If `TMPDIR` is unset, the plugin uses the system temp directory.
Symlinks are skipped.

Focus stays in OpenCode. Press the shortcut again to close the tail pane, then
again to select the latest file. The running tail does not switch automatically
when a newer file appears.
The last 10 lines appear initially, followed by appended content. `tail -F`
continues following the path if the file is replaced.

The tmux border caption shows `OpenCode tail: <file path>`. If border captions
are disabled, the plugin enables them at the top of panes for that window.
Existing top or bottom placement is preserved. Captions enabled by the plugin
turn off when the last tail pane in the window closes, including via `Ctrl+C`.
Captions that were already enabled stay enabled.
The caption uses tmux's existing `pane-border-format`,
which must include `#{pane_title}` to display the filename.

When `bat` is installed, the output uses syntax highlighting based on the
filename, with no pager or decorations. Files with unknown extensions stay
plain. If `bat` is unavailable, the pane runs plain `tail -F`.

## Session selection

Inside a session, the plugin chooses the most recently modified existing file
written by that session or any of its descendant sessions. It reads paginated
tool history, including running writes. Read-only references and failed calls
do not qualify. If no session file qualifies, or you are on the home screen,
it falls back to the latest file anywhere under `$TMPDIR/opencode`.

Recognized writes include `write`, `edit`, patch destinations, shell output
redirects, `tee`, `touch`, `mkdir`, and the destinations of `cp`, `mv`, and
`install`. Command-local variable assignments are expanded in these paths,
and uppercase `*LOG=...` assignments passed to script invocations also qualify.
Written directories contribute their newest regular file. Shell
detection is conservative: arbitrary script internals and
tools nested inside Code Mode are not inspected. Both absolute paths and
`$TMPDIR` references work, including canonical macOS `/private` paths.
This is a history-based association, not proof of exclusive file ownership.
History lookup failures show an error rather than silently selecting another
session's file.

Each OpenCode pane owns its own tail pane, marked with `@opencode-tail` in tmux.
The toggle survives plugin reloads. You can also focus the tail pane and press
`Ctrl+C` to close it. Outside tmux, or when there are no files, the command shows
a warning without opening a pane.

The command is also available as **Toggle temp-file tail** in the
command palette. Both `cli.base.json` alternates load the plugin. After changing
the plugin list, launch OpenCode from a new shell to refresh
`OPENCODE_CLI_CONFIG_CONTENT`.

## Tests

From this directory, run:

```sh
mise exec bun@1.3.10 -- bun test
```
