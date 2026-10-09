# queue-command

A CLI plugin that adds a `/queue` slash command. It queues a message for the current
session instead of sending it right away, like pressing **Ctrl+X**, then **Enter** in
the composer.

```text
/queue run the full test suite once you're done
```

## Behavior

- **Busy session:** the message waits in the session's queue and runs after the current
  turn finishes.
- **Idle session:** the message starts a new turn right away.
- A toast confirms the queued message and shows a short preview.

Queued messages appear in the queued-prompts manager (**Ctrl+X**, then **Q**). You can
undo or delete them there.

The command is also available from the command palette as **Queue message**.

## Limitations

- The plugin sends the message as plain text. File mentions such as `@src/auth.ts`, pasted
  images, and skill attachments aren't turned into attachments.
- The command works only while a session is open. On the home screen, it shows a
  warning and queues nothing.

## How it works

The command calls `client.session.prompt` with `delivery: "queue"` and `resume: true`
for the session shown in the TUI. `resume: true` is what starts an idle session.

The plugin registers its keymap layer while an `app` slot renders, so that
`Keymap.Provider` is available on OpenCode v2.0.22.

## Installation

The plugin loads through a path entry in `plugins` in both `cli.base.json` alternates:

```json
"./local-plugins/tui/queue-command"
```

Open a new shell after editing `cli.base.json` so that `OPENCODE_CLI_CONFIG_CONTENT`
picks up the change, then restart the TUI.

## Tests

Run the tests from the plugin directory:

```sh
mise exec bun@1.3.10 -- bun test
```
