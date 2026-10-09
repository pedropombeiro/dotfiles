# forge-review-status

A CLI plugin that shows a session's GitHub PR or GitLab MR in the prompt footer.
Both `cli.base.json` alternates load it, so the repository selects the forge on
either machine. GitLab explicit targets retain review-feedback notifications.
GitHub support is status-only and never resumes the agent.

The plugin was named `gitlab-mr-status` before it supported GitHub. GitHub uses
`gh`'s stored login; GitLab uses `glab`'s.

## Merge request selection

The plugin picks each session's PR/MR in this order:

1. The target stored by `set_session_target`, read through the RPC that
   `opencode-forge-session-title` 1.3.0 and later registers.
1. A PR/MR number in the title prefix that plugin writes, such as `!456` in
   `[#123, !456]` or `#108` in `[#42, #108]`.
1. The checked-out branch's open PRs/MRs.

An explicit target that isn't a PR/MR, such as an issue, shows none.

Title references are read only on the forges that the checkout has remotes for. The
same syntax can name an issue, so the plugin tries each reference in order and uses
the first that the forge confirms is a PR/MR. Otherwise, it falls back to the branch.

## Footer and commands

GitHub status includes checks on the head commit, requested reviewers, the review
decision, unresolved review threads, draft state, and conflicts. Unknown
mergeability stays unknown rather than appearing conflict-free. Thread and check
connections are paginated, with partial results labeled when a limit is reached.
The review decision does not claim that all branch-protection requirements are met.

For either forge, explicit targets take priority over title references and the
checked-out branch. An explicit issue suppresses fallback, and an unresolved
explicit PR/MR never falls back to a different branch target. Branch discovery
distinguishes forks with the same branch name and respects push/tracking branch
names. The personal configuration works without the optional target RPC.

The footer shows the MR's pipeline status, unresolved thread count, conflicts,
approval, and a running Duo review. The MR number and pipeline status are links.

The footer shows `approved` only when all of the following are true:

- GitLab reports that the approval requirements are met.
- At least one person approved. Bot approvals, such as Duo's, don't count, because
  they can satisfy rules that require no approvals.
- Every human reviewer approved.

While human reviewers haven't approved, the footer shows `awaiting @username`
instead, or `awaiting N reviewers` for more than two.

- `/forge-status` opens a dialog with full status and a refresh action. Aliases:
  `/mr-status` and `/pr-status`.
- `/forge-open` opens the PR/MR in the browser. Aliases: `/mr-open` and `/pr-open`.

Both are also available from the command palette.

The plugin reads GitLab through `glab api graphql`, so it uses `glab`'s stored login. It
caches each session's status and polls every 2 minutes while an open MR is shown, so
switching tabs reuses cached data until the next poll is due. While an automated
review, such as GitLab Duo's, runs, it polls every 30 seconds.

## Review notifications

For a session's open `set_session_target` PR/MR, the plugin tells the agent about
reviews. Each notification is a queued synthetic message that resumes the session,
followed by a toast. PRs/MRs from the session title or the branch don't get
notifications.

Each kind of notification depends on a capability of the target's forge:

| Notification | Capability | GitLab | GitHub |
| --- | --- | --- | --- |
| Automated review finished with feedback | `automatedReview` | GitLab Duo | Not supported |
| New human review feedback | `feedback` | MR comments | Not supported |

GitHub targets therefore show status only.

The plugin keeps polling the PR/MR while the session is hidden, but only after the TUI
has shown that session at least once since it started. It stops when the PR/MR merges
or closes, or the session's target changes.

### Automated reviews

When an automated review finishes with feedback, the plugin asks the agent to read the
reviewer's comments. For GitLab Duo, that means a final state of `REVIEWED` or
`REQUESTED_CHANGES`. Any other final state, such as `APPROVED`, sends nothing.

### Human reviews

The plugin announces new comments and replies from people other than you and bots,
including comments posted with an approval. It waits until none of those people's
unresolved comments, new or already announced, has been added or edited for 5 minutes.
Any such activity restarts the wait for the whole batch, so expect one message 5 to 7
minutes after the review goes quiet. Resolved threads are skipped and don't count as
activity.

Each comment has an `order` that its forge guarantees grows with each new comment;
GitLab uses the note ID. The first look at a PR/MR records its highest order as a
baseline. Announced comment IDs are stored per session and PR/MR. Older comments
therefore never count as new, and a restart replays nothing but still catches comments
posted in the meantime.

Limitations:

- On GitLab, the plugin reads the newest 2,000 comments. On busier MRs, edits to older
  comments don't count as activity.
- Two TUIs that watch the same session can occasionally both send a notification.
- A failed send shows an error toast and is retried after 10 minutes.

## Options

Set options with the object form of the `plugins` entry in `cli.base.json##class.Work`:

```json
{
  "package": "./local-plugins/tui/forge-review-status",
  "options": { "notifyHumanReviews": false }
}
```

| Option | Default | Description |
| --- | --- | --- |
| `hosts` | `["gitlab.com"]` | GitLab hosts whose remotes the plugin recognizes. |
| `githubHosts` | `["github.com"]` | GitHub hosts, including explicitly configured enterprise hosts. |
| `pollSeconds` | `120` | Normal polling interval. Running automated reviews poll at 30 seconds or this value, whichever is lower. |
| `notifyAutomatedReviews` | `true` | Tell the agent when an automated review, such as GitLab Duo's, finishes with feedback. The former name, `notifyDuoReview`, still works. |
| `notifyHumanReviews` | `true` | Tell the agent about new human review feedback. |

## Code layout

- `tui.tsx` connects the store, watchers, footer, and commands.
- `src/forge.ts` defines the forge-neutral `ReviewRequest` and review-comment types,
  `ForgeError`, the `Forge` interface that each forge adapter implements, and
  `ForgeTraits` with its optional `automatedReview` and `feedback` capabilities.
- `src/gitlab.ts` and `src/github.ts` provide the `GitLabForge` and `GitHubForge`
  adapters. Each owns its API calls, pagination, error classification, and status
  normalization.
- Each forge module also exports its traits: everything about the forge apart from API
  access. That covers the hosts it recognizes, its adapter factory, its PR/MR URLs,
  its vocabulary, how it writes `!45` or `#7`, its title references, and the footer
  and dialog content for its own status fields. Traits are stateless, so code needs
  only a host, a URL, or a request. Adapters expose them as `forge.traits`.
- `src/forges.ts` registers each forge's traits and iterates over them to classify
  hosts, open adapters, and parse URLs. Its `traitsOf(request)` returns the traits of
  a request's forge.
- `src/locate.ts` picks the session's PR/MR: the explicit target, a title reference,
  then the branch.
- `src/store.ts` caches lookups, polls, and backs off after failures.
- `src/format.ts` renders the footer and status dialog for both forges.
- `src/session-watch.ts` and `src/holds.ts` keep one polling hold per session and ignore
  loads of stale cache keys.
- `src/automated-review-watch.ts` and `src/human-review-watch.ts` decide when to
  notify. They work with any forge that has the matching capability.
- `src/gitlab-feedback.ts` reads GitLab MR comments for GitLab's `feedback` capability.

To add a forge, add its kind to `ForgeKind` and `ReviewRequest`, implement `Forge`
and `ForgeTraits`, and add the traits to the registry in `src/forges.ts`. To support
notifications, implement the `automatedReview` or `feedback` capability. Shared code
should never compare a request's or host's forge against a specific forge name. Ask
the forge's traits, or check for a capability, instead.

## Tests

Run the tests from this directory:

```sh
mise exec bun@1.3.10 -- bun test
```

For how local plugins load and the rules for editing them, see
[Explicitly loaded plugin directories](../../../../../.agents/docs/opencode.md#explicitly-loaded-plugin-directories).
