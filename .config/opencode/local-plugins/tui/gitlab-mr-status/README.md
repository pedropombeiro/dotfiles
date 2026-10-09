# gitlab-mr-status

A CLI plugin that shows the status of a session's GitLab merge request in the prompt
footer and tells the agent when the MR gets review feedback. It loads only on Work
machines, through `cli.base.json##class.Work`.

## Merge request selection

The plugin picks each session's MR in this order:

1. The target stored by `set_session_target`, read through the RPC that
   `opencode-forge-session-title` 1.3.0 and later registers.
1. The MR number in the title prefix that plugin writes, such as `[#123, !456]`.
1. The checked-out branch's open MR.

An explicit target that isn't an MR, such as an issue, shows no MR.

## Footer and commands

The footer shows the MR's pipeline status, unresolved thread count, conflicts,
approval, and a running Duo review. The MR number and pipeline status are links.

- `/mr-status` opens a dialog with the full status and a refresh action.
- `/mr-open` opens the MR in the browser.

Both are also available from the command palette.

The plugin reads GitLab through `glab api graphql`, so it uses `glab`'s stored login. It
caches each session's status and polls every 2 minutes while an open MR is shown, so
switching tabs reuses cached data until the next poll is due. While Duo reviews an MR,
it polls every 30 seconds.

## Review notifications

For a session's open `set_session_target` MR, the plugin tells the agent about reviews.
Each notification is a queued synthetic message that resumes the session, followed by a
toast. MRs from the session title or the branch don't get notifications.

The plugin keeps polling the MR while the session is hidden, but only after the TUI has
shown that session at least once since it started. It stops when the MR merges or
closes, or the session's target changes.

### Duo reviews

When Duo's review ends as `REVIEWED` or `REQUESTED_CHANGES`, the plugin asks the agent
to read Duo's feedback. Any other final state, such as `APPROVED`, sends nothing.

### Human reviews

The plugin announces new comments and replies from people other than you and bots,
including comments posted with an approval. It waits until none of those people's
unresolved comments, new or already announced, has been added or edited for 5 minutes.
Any such activity restarts the wait for the whole batch, so expect one message 5 to 7
minutes after the review goes quiet. Resolved threads are skipped and don't count as
activity.

The first look at an MR records its highest note ID as a baseline. Announced note IDs
are stored per session and MR. Because note IDs only grow, older comments never count as
new, and a restart replays nothing but still catches comments posted in the meantime.

Limitations:

- The plugin reads the newest 2,000 comments. On busier MRs, edits to older comments
  don't count as activity.
- Two TUIs that watch the same session can occasionally both send a notification.
- A failed send shows an error toast and is retried after 10 minutes.

## Options

Set options with the object form of the `plugins` entry in `cli.base.json##class.Work`:

```json
{
  "package": "./local-plugins/tui/gitlab-mr-status",
  "options": { "notifyHumanReviews": false }
}
```

| Option | Default | Description |
|---|---|---|
| `hosts` | `["gitlab.com"]` | GitLab hosts whose remotes the plugin recognizes. |
| `pollSeconds` | `120` | Normal polling interval. Duo reviews poll at 30 seconds or this value, whichever is lower. |
| `notifyDuoReview` | `true` | Tell the agent when a Duo review ends with feedback. |
| `notifyHumanReviews` | `true` | Tell the agent about new human review feedback. |

## Code layout

- `tui.tsx` connects the store, watchers, footer, and commands.
- `src/store.ts` caches lookups, polls, and backs off after failures.
- `src/session-watch.ts` and `src/holds.ts` keep one polling hold per session and ignore
  loads of stale cache keys.
- `src/duo-watch.ts` and `src/human-review-watch.ts` decide when to notify.
- `src/review-feedback.ts` and `src/gitlab.ts` read GitLab.

## Tests

Run the tests from this directory:

```sh
mise exec bun@1.3.10 -- bun test
```

For how local plugins load and the rules for editing them, see
[Explicitly loaded plugin directories](../../../../../.agents/docs/opencode.md#explicitly-loaded-plugin-directories).
