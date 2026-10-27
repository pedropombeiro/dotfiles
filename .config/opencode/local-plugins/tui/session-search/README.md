# session-search

A CLI plugin that searches previous OpenCode sessions and opens a match, without an
agent turn. Open it with **`<leader>f`** (**Ctrl+X**, then **F**), from the command
palette (**Ctrl+P**) as **Search sessions**, or with the `/search-session` slash command.

```text
/search-session palette entry
```

## Behavior

- Without arguments, the command asks for a keyword or sentence.
- It runs the `session-search` skill script, which shows a toast while it works. A search
  takes several seconds, longer when it falls back to tool output.
- The results open in a searchable list. Sessions of the current project come first.
  Each entry shows the date of its last match and an excerpt, plus the directory for
  sessions of other projects. The title notes when the results come from a fallback
  search, such as all words in any order or tool output.
- **Enter** focuses the session's tab, or switches to it for child sessions or when tabs
  are off. Sessions of other projects stay closed, and a toast shows the
  `opencode --session <id>` command to reopen them.
- **Ctrl+S** (**Summarize here**) queues a prompt in the current session. The prompt asks
  the agent to read the session's matches with the skill and summarize them.
- When nothing matches, a toast lists the searches that ran.

The search excludes the session on screen and shows at most 30 sessions.

## How it works

The plugin runs `~/.agents/skills/session-search/scripts/search.py` with
`--format json` in the CLI process. It sets `OPENCODE_SESSION_ID` to the displayed
session, which the script excludes and uses to detect the current project. On the home
screen, the script uses the project of the location's directory instead.

The script reads the local database, so the plugin searches this machine's sessions even
when the TUI is attached to a remote server.

The plugin registers its keymap layer while an `app` slot renders, so that
`Keymap.Provider` is available on OpenCode v2.0.22. See `queue-command` for details.

The agent-driven flow still exists: when you ask the agent to find a session, it loads
the `session-search` skill and opens matches with the `open_session` tool from
`session-open`.

## Installation

The plugin loads through a path entry in `plugins` in both `cli.base.json` alternates:

```json
"./local-plugins/tui/session-search"
```

Open a new shell after editing `cli.base.json` so that `OPENCODE_CLI_CONFIG_CONTENT`
picks up the change, then restart the TUI.

## Tests

Run the tests from the plugin directory:

```sh
mise exec bun@1.3.10 -- bun test
```
