# last-session-tab

A CLI plugin that switches to the previously active session tab so pressing the
shortcut repeatedly alternates between the two most recently used tabs (`A ↔ B`).

## Usage

Press ``<leader>` `` (`Ctrl+X`, then `` ` `` by default) or choose
**Switch to last session tab** in the command palette.

Both `cli.base.json` alternates load the plugin. After changing the plugin list
or options, launch OpenCode from a new shell to refresh
`OPENCODE_CLI_CONFIG_CONTENT`.

## Configuration

Override or disable the keybinding via plugin `options.bind` in `cli.base.json`
or `cli.json`:

```jsonc
{
  "plugins": [
    {
      "package": "./local-plugins/tui/last-session-tab",
      "options": {
        "bind": "<leader>p" // or false / "none" to keep only the command palette entry
      }
    }
  ]
}
```

OpenCode's top-level `keybinds` object in `cli.json` only accepts built-in
command IDs, so plugin keybinding overrides use `options.bind`.

## Behavior

- Tracks visited root-session tabs in most-recently-used (MRU) order for the
  lifetime of the TUI process.
- Viewing a child subagent session inside the current tab keeps the parent root
  tab as the current tab, so ``<leader>` `` still returns to the previous root
  session tab.
- Closed tabs are skipped automatically; if the immediately previous tab was
  closed, the shortcut switches to the next most recently visited open tab.
- From the home screen, the shortcut returns to the most recently active open
  session tab.
- Shows an info toast (`No previous session tab`) when no previous tab is
  available.

## Tests

From this directory, run:

```sh
mise exec bun -- bun test
```

For how local plugins load and the rules for editing them, see
[Explicitly loaded plugin directories](../../../../../.agents/docs/opencode.md#explicitly-loaded-plugin-directories).
