# session-open

A server plugin that adds the `open_session` tool, which focuses a past session in the
terminal. The `session-search` skill and the `/search-session` command use it.

## Behavior

- The tool accepts only sessions of the caller's project: the same project ID, or the
  same resolved directory for sessions outside a repository (project `global`).
- The service can't drive the terminal, so the tool emits an RPC event and waits for a
  reply.
- The plugin's `tui.tsx` handles the event only in the terminal that shows the calling
  session or one of its ancestors. It focuses the target's tab, or navigates to the
  session for child sessions or when tabs are off, and replies.
- The tool fails after 3 seconds without a reply.
- Pass `close_source: true` to close the source tab after the destination opens.
  The default is `false`. Closing a tab preserves the conversation in history.
  With tabs disabled, the tool only navigates. It keeps the source tab open if
  the destination shares its root session or navigation does not reach the target.

## Tests

Run the tests from this directory:

```sh
mise exec bun@1.3.10 -- bun test
```

For how local plugins load and the rules for editing them, see
[Explicitly loaded plugin directories](../../../../../.agents/docs/opencode.md#explicitly-loaded-plugin-directories).
