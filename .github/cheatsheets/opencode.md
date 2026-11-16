# OpenCode cheat sheet

Configuration: [server config](../../.config/opencode/opencode.json%23%23template),
[Work terminal config](../../.config/opencode/cli.base.json%23%23class.Work), and
[default terminal config](../../.config/opencode/cli.base.json%23%23default).

Quick reference for Pedro's OpenCode V2 setup. `Leader` means press `Ctrl+X`,
release it, then press the next key. `Alt` is Option on macOS.
Open this sheet with tmux `Prefix h` or `cheat --local opencode`.
The tmux prefix is `Ctrl+B`, separate from OpenCode's leader.

## Everyday controls

| Task | Shortcut or command | Note |
| --- | --- | --- |
| Open OpenCode | `oc` or `opencode PATH` | Uses the shared background service |
| Find a command or open settings | `Ctrl+P` | Search the command palette |
| Choose an agent | `Leader a` or `Tab` | `Tab` cycles in reverse. Plan is the default agent. |
| Choose a model | `Leader m` | `Ctrl+T` cycles its reasoning variants |
| Toggle permission mode | `Shift+Tab` or `/permission-mode` | Global `prompt` / `autoaccept` preference, not an agent switch |
| Interrupt a running turn | `Esc` | |
| Edit the prompt externally | `Leader e` | |
| Add a newline | `Ctrl+J` or `Alt+Enter` | `Enter` submits |
| Show or hide the sidebar | `Leader b` | `Ctrl+Alt+T` toggles the scrollbar |
| Page through the transcript | `Page Up` / `Page Down` | Work also maps `Home` / `End` to paging |
| Jump to the first / last message | `Ctrl+G` / `Ctrl+Alt+G` | Same on every machine |

The [tracked terminal config](../../.agents/docs/opencode.md#terminal-config) overrides UI settings
for these custom bindings. See the [upstream keybind reference](https://opencode.ai/docs/cli/keybinds)
for other defaults.

## Sessions and context

| Task | Shortcut or instruction | Note |
| --- | --- | --- |
| Create / find a session | `Leader n` / `Leader l` | `Ctrl+O` opens recent sessions and projects |
| Search past session content | `Leader f` or `/search-session QUERY` | Searches titles and messages. `Enter` opens a same-project result. `Ctrl+S` requests a summary here. |
| Switch session tabs | `Alt+Down` / `Alt+Up` | |
| Close / reopen a tab | `Leader w` / `Ctrl+Shift+T` | Closing a tab doesn't delete the session |
| Fork a session | `Ctrl+P`, search for fork | Choose the message to branch from |
| Compact context | `Leader c` | Read summaries with `/compaction-history` |
| Queue a follow-up | `Leader Enter` or `/queue MESSAGE` | Waits for a busy turn to finish. Starts immediately if idle. |
| Manage queued prompts | `Leader q` | `/queue` is plain text. Use the composer for attachments. |
| Move to a worktree | `Ctrl+P`, search for move session | In the dialog, `Ctrl+A` creates a worktree |
| Save a handoff | Ask: `Save a handoff for this task` | Load the returned file path in the next session |

## Local extensions

| Task | Command | Note |
| --- | --- | --- |
| Inspect timing and reported cache reuse | `/session-metrics` | `c` toggles descendants, `r` refreshes, and `f` toggles fullscreen |
| Inspect cache expiry and estimated costs | `/cache` | Cache Coach. No default shortcut. |
| Inspect the telemetry collector | `/otel` | No default shortcut. |
| Follow a temporary output file in tmux | `Leader o` | Selects the most recently modified qualifying session-written file. Toggle off/on to reselect. |
| Inspect PR/MR status | `/forge-status` | `/forge-open` opens it in the browser |
| Browse review and lifecycle updates | `/forge-feedback` | Configured summaries arrive after active work finishes |
| Track issues or PRs/MRs | Give the agent their URLs | Say `Return to the checked-out branch` to restore branch-based targeting |

Details: [Session Finder](https://github.com/pedropombeiro/opencode-plugins/tree/main/packages/session-finder),
[session metrics](../../.config/opencode/local-plugins/tui/session-metrics/README.md),
[temp-file tail](../../.config/opencode/local-plugins/tui/temp-file-tail/README.md),
[permission mode](../../.config/opencode/local-plugins/tui/permission-mode/README.md),
[queue command](../../.config/opencode/local-plugins/tui/queue-command/README.md),
and [Forgekeeper](https://github.com/pedropombeiro/opencode-plugins/tree/main/packages/forgekeeper).

### Plugin dialog shortcuts

These keys apply only inside the named dialog.

| Dialog | Keys | Action |
| --- | --- | --- |
| `/forge-status` | `Ctrl+R` | Refresh status |
| `/forge-feedback` | `Ctrl+A` | Start work on the selected feedback. Can edit files. |
| `/forge-feedback` | `Ctrl+T` | Retry feedback work after confirmation. Can repeat earlier changes. |
| `/forge-feedback` | `Ctrl+D` | Acknowledge the update locally, without replying or resolving a remote thread |
| `/forge-feedback` | `Ctrl+R` | Summarize the update in its session |
| `/forge-feedback` | `Ctrl+S` | Pause or resume monitoring |
| `/forge-feedback` | `Enter` | Choose a link from the selected update |
| `/forge-status` or `/otel` | `Tab`, `Shift+Tab`, `Left`, `Right` | Select an action, then press `Enter` to activate it |
| Compaction history or multi-PR/MR open picker | `Ctrl+W` | Close the picker |

## Configuration and troubleshooting

Paths below are relative to `~/.config/opencode/` unless stated otherwise.

| Change or symptom | File or first action |
| --- | --- |
| Change agents, providers, permissions, or server plugins | Edit `opencode.json##template`, then run `yadm alt`. Never edit the rendered file as the source of truth. |
| Change managed keybindings or terminal plugins | Edit `cli.base.json##class.Work` or `cli.base.json##default`, then launch OpenCode from a fresh shell. |
| Change theme, sidebar, or other UI preferences | Use **Open settings** in the palette. OpenCode owns the untracked `cli.json`. Managed base settings take precedence. |
| Force a config reload | Run `opencode reload`. Ordinary watched config changes apply automatically. |
| Apply model or other service environment changes | From a fresh interactive shell, run `mise exec -- opencode service restart`. This affects the shared service. |
| Check service health | Run `opencode service status`, then `opencode api get /api/info`. |
| Isolate a shared-service problem | Compare with `opencode --standalone`. |
| Inspect config sources | Run `opencode debug config`. It shows sources, not the merged result. |
| Read logs | Follow `~/.local/share/opencode/log/opencode.log`. Filter `role=server` or `role=cli`. Redact sensitive content before sharing. |
| Permission toggle refuses to change | Check for `--auto` or `session.permissions` in `OPENCODE_CLI_CONFIG_CONTENT`. |

See [OpenCode policies](../../.agents/docs/opencode.md) for configuration ownership, model defaults,
and telemetry, or [upstream troubleshooting](https://opencode.ai/docs/troubleshooting)
for diagnostics. Don't delete the database or service files to troubleshoot.
