# permission-mode

A CLI plugin that toggles the global permission preference, `session.permissions` in
`~/.config/opencode/cli.json`, between `prompt` and `autoaccept`.

## Usage

Press Shift+Tab, run `/permission-mode`, or choose **Toggle permission mode** in the
command palette. A toast shows the new mode.

Both `cli.base.json` alternates disable `agent.cycle` to free Shift+Tab. For details,
see [Terminal config](../../../../../.agents/docs/opencode.md#terminal-config).

## Behavior

- The plugin preserves the other settings in the untracked `cli.json` and replaces the
  file atomically, so OpenCode's config watcher reloads it. Other running TUIs also
  reload the preference.
- It respects `XDG_CONFIG_HOME` when it locates `cli.json`.
- It refuses to change the mode when one of these overrides the file:
  - OpenCode was started with `--auto`.
  - `OPENCODE_CLI_CONFIG_CONTENT` sets `session.permissions`.
- It rejects a `session.permissions` value other than `prompt` or `autoaccept`.

## Tests

Run the tests from this directory:

```sh
mise exec bun@1.3.10 -- bun test
```

For how local plugins load and the rules for editing them, see
[Explicitly loaded plugin directories](../../../../../.agents/docs/opencode.md#explicitly-loaded-plugin-directories).
