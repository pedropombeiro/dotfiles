# forge-session

A local plugin that tracks the issue or PR/MR a session works on. It prefixes the session
title with its references, shows the PR/MR status in the prompt footer, and tells the agent
about new review feedback. It supports GitLab and GitHub. The status and review
notifications are optional; see [Keep only session titles](#keep-only-session-titles).

It merges two plugins, which it replaces:

- The published [`opencode-forge-session-title`](https://www.npmjs.com/package/opencode-forge-session-title)
  1.3.0, which became the server entry point, `index.ts`.
- The local `forge-review-status`, which became the CLI entry point, `tui.tsx`.

Both `opencode.json` alternates load it as `./local-plugins/server/forge-session`. OpenCode
then loads `tui.tsx` in the CLI, so `cli.base.json` has no entry for it. It is a local trial;
once the design settles, it can be published from
[`opencode-plugins`](https://github.com/pedropombeiro/opencode-plugins).

## Session targets

The server registers the `set_session_target` tool and adds instructions to the agent's
context. When you establish or change the primary issue, PR, or MR, the agent sets its full
URL as the session target. Background references, comparisons, and dependencies keep the
current target. After the agent creates a PR/MR for the current task, it sets the new PR/MR
as the target, passing the current issue as `issue_url`.

For example, if the title starts with `[#123, !45]` and you ask the agent to review MR `!456`,
the prefix becomes `[!456]`. Without `issue_url`, the server reads the PR/MR's source branch
and takes the issue number from its name, so reviewing an MR from `321-fix-timeout` produces
`[#321, !456]`.

Targets persist per session across plugin reloads. Calling `set_session_target` with
`target: "branch"` returns to branch-based naming. Child sessions and untitled sessions are
skipped.

Target URLs can name a GitLab MR, issue, or work item on any host, or a GitHub PR or issue.
GitHub URLs are accepted on any host that isn't recognizably GitLab, so GitHub Enterprise
targets work.

## Branch-based naming

Without an explicit target, the title follows the checked-out branch:

1. The prefix starts with the issue number from the branch name, or the branch name
   without one.
2. It adds the newest open PR/MR from the branch, or `!N/A` (GitLab) or `#N/A` (GitHub)
   until one exists.

The title is reconciled after target changes, title changes, and successful agent runs.
Text you add to the title, including your own bracketed prefixes, is kept.

The default branch and branches named `main`, `master`, `develop`, or `HEAD` get no prefix.

The branch's remote, pushed branch name, and forge come from the same repository discovery
as the status footer. That discovery uses the branch's push or upstream remote, recognizes
forks, and classifies hosts with the `hosts` and `githubHosts` options.

| Pattern                           | Example branch          | Issue |
| --------------------------------- | ----------------------- | ----- |
| `<prefix>/<number>-<description>` | `feature/123-add-login` | `123` |
| `<number>-<description>`          | `123-fix-typo`          | `123` |
| `<description>-<number>`          | `fix-typo-123`          | `123` |
| `<prefix>/<number>/<description>` | `user/123/some-work`    | `123` |
| `issue-<number>`, `gh-<number>`   | `gh-42-improve-perf`    | `42`  |
| `fix-<number>`, `feat-<number>`   | `fix-99`                | `99`  |

## Status footer

The CLI picks each session's PR/MR in this order:

1. The explicit target, read from the server over RPC.
1. A PR/MR number in the title prefix, such as `!456` in `[#123, !456]`.
1. The checked-out branch's open PRs/MRs.

An explicit target that isn't a PR/MR, such as an issue, shows none. An unresolved explicit
PR/MR never falls back to the branch.

The footer shows checks or the pipeline, unresolved threads, conflicts, approval, and a
running GitLab Duo review. GitHub also shows a requested change. Unknown mergeability stays
unknown rather than appearing conflict-free.

The footer shows `approved` only when GitLab reports that approval requirements are met,
at least one person approved, and every human reviewer approved. Bot approvals, such as
Duo's, don't count. While human reviewers haven't approved, it shows `awaiting @username`,
or `awaiting N reviewers` for more than two.

Clicking the PR/MR number or pipeline opens it in the browser. Clicking any other indicator
opens the status dialog. These commands are also available from the command palette:

- `/forge-status` opens a dialog with full status and a refresh action. Aliases:
  `/mr-status` and `/pr-status`.
- `/forge-open` opens the PR/MR in the browser. Aliases: `/mr-open` and `/pr-open`.

The CLI caches each session's status and polls every 2 minutes while an open PR/MR is
shown, or every 30 seconds while an automated review runs.

## Review notifications

For an explicit target that is an open PR/MR, the CLI tells the agent about reviews. Each
notification is a queued synthetic message that resumes the session, followed by a toast.
PRs/MRs from the title or the branch don't get notifications.

| Notification | GitLab | GitHub |
| --- | --- | --- |
| An automated review finished with feedback | GitLab Duo | Not supported |
| New human review feedback | MR comments | Not supported |

- **Automated reviews**: Duo's final state of `REVIEWED` or `REQUESTED_CHANGES` asks the
  agent to read its comments. Other final states, such as `APPROVED`, send nothing.
- **Human reviews**: new comments and replies from people other than you and bots are
  announced once none of their unresolved comments has changed for 5 minutes. Expect one
  message 5 to 7 minutes after the review goes quiet. Resolved threads are skipped.

The first look at a PR/MR records its newest comment as a baseline, so older comments never
count as new. Announced comments are stored per session and PR/MR, so a restart replays
nothing but still catches comments posted in the meantime.

Polling continues while the session is hidden, but only after the CLI has shown that session
at least once since it started. It stops when the PR/MR merges or closes, or the session's
target changes.

Limitations:

- On GitLab, the CLI reads the newest 2,000 comments. On busier MRs, edits to older comments
  don't count as activity.
- Two CLIs that watch the same session can occasionally both send a notification.
- A failed send shows an error toast and is retried after 10 minutes.

## Options

Set options with the object form of the `plugins` entry in `opencode.json`:

```jsonc
{
  "package": "./local-plugins/server/forge-session",
  "options": { "notifyHumanReviews": false }
}
```

| Option | Default | Used by | Description |
| --- | --- | --- | --- |
| `reviewStatus` | `true` | CLI | Show the PR/MR status and notify the agent about reviews. Set to `false` to keep only session targets and titles. |
| `hosts` | `["gitlab.com"]` | Both | GitLab hosts whose remotes are recognized, besides hosts named `gitlab.*`. |
| `githubHosts` | `["github.com"]` | Both | GitHub hosts, including GitHub Enterprise hosts. |
| `pollSeconds` | `120` | CLI | Normal polling interval. Running automated reviews poll at 30 seconds or this value, whichever is lower. |
| `notifyAutomatedReviews` | `true` | CLI | Tell the agent when an automated review finishes with feedback. The former name, `notifyDuoReview`, still works. |
| `notifyHumanReviews` | `true` | CLI | Tell the agent about new human review feedback. |

The CLI entry point reads its options from the server over RPC, because OpenCode passes
the `opencode.json` options to the server entry point. It uses the options of the location
the CLI started in, and reads them only when it loads, so restart the CLI after changing
them. If the server doesn't answer, the CLI falls back to its own options and the defaults.

### Keep only session titles

To keep the behavior of `opencode-forge-session-title` alone, turn off review status:

```jsonc
{
  "package": "./local-plugins/server/forge-session",
  "options": { "reviewStatus": false }
}
```

The server still registers `set_session_target`, adds the agent guidance, and maintains the
title prefix. The CLI entry point then registers nothing: no footer, no `/forge-status` or
`/forge-open`, no polling, and no review notifications.

## RPC

The server registers an [RPC](https://opencode.ai/v2/docs/build/plugins/rpc) that the CLI
uses, defined in `src/rpc.ts`:

- `target({ sessionID })` returns `{ url, issueUrl? }` for an explicit target, and `{}` in
  branch mode.
- `options({})` returns the CLI entry point's options from the `opencode.json` entry.
- `targetChanged` fires after `set_session_target` runs. It omits `url` in branch mode.

## Migration from the separate plugins

| Entry point | Plugin ID | Stored state |
| --- | --- | --- |
| Server | `opencode-forge-session-title` | Session targets and owned title prefixes, carried over |
| CLI | `pedropombeiro.forge-session` | Notification records and human-review baselines |

The server keeps `opencode-forge-session-title`'s plugin and RPC IDs, so stored targets
carry over. The CLI entry point has its own ID, so it started without
`forge-review-status`'s records. Each MR it watches records a new baseline on first look,
so comments posted before then aren't announced.

Never load this plugin together with either predecessor. The server would collide with
`opencode-forge-session-title`'s IDs, and alongside `forge-review-status` the footer and
review notifications would appear twice.

## Code layout

- `index.ts` wires the server: the forge catalog from the options, and title lookups.
- `src/server.ts` registers the tool, the agent guidance, title reconciliation, and the RPC.
- `src/target.ts` parses, normalizes, and formats session targets, and classifies the RPC
  output for the CLI.
- `src/title.ts` extracts branch issue numbers and reconciles title prefixes.
- `src/options.ts` selects the CLI's options and resolves them through the RPC.
- `src/lookups.ts` answers the server's forge questions through the shared catalog:
  the branch's newest PR/MR number and a PR/MR's source branch.
- `tui.tsx` reads its options, then connects the status store, watchers, footer, and
  commands.
- `src/forge.ts` defines the forge-neutral types, the `Forge` adapter interface, and
  `ForgeTraits` with its optional `automatedReview` and `feedback` capabilities.
- `src/gitlab.ts` and `src/github.ts` provide each forge's adapter and traits. Adapters own
  API calls, pagination, error classification, and status normalization. Traits cover
  everything else: hosts, URL parsing, reference syntax, vocabulary, and forge-specific
  footer and dialog content.
- `src/forges.ts` registers each forge's traits, classifies hosts, opens adapters, and
  parses URLs.
- `src/git.ts` resolves a checkout's remotes, branch, and pushed branch name.
- `src/locate.ts` picks the CLI's PR/MR. `src/store.ts` caches lookups, polls, and backs off
  after failures. `src/format.ts` renders the footer and dialog.
- `src/session-watch.ts`, `src/holds.ts`, `src/automated-review-watch.ts`,
  `src/human-review-watch.ts`, and `src/gitlab-feedback.ts` decide when to notify the agent.

Shared code never compares a forge against a specific name. It asks the forge's traits, or
checks for a capability, instead. To add a forge, add its kind to `ForgeKind` and
`ReviewRequest`, implement `Forge` and `ForgeTraits`, and register the traits in
`src/forges.ts`.

## Tests

Run the tests from this directory:

```sh
mise exec bun@1.3.10 -- bun test
```

For how local plugins load and the rules for editing them, see
[Explicitly loaded plugin directories](../../../../../.agents/docs/opencode.md#explicitly-loaded-plugin-directories).
