# session-metrics

A CLI plugin for OpenCode V2 that shows compaction, cache, and timing metrics in
the sidebar. When the sidebar is hidden, a footer contribution shows the active
time, and only when it fits the allocated space. Compaction and cache metrics
stay in the sidebar and the details panel. The native context/cost and forge
indicators take priority.

For sessions that run on the OpenCode Go subscription, the plugin also shows the
Go allowance, in the sidebar and in the footer, and warns when the local cost
proxy is down.

## Commands

- `/session-metrics` opens a session panel. Press `c` to toggle descendants, `r`
  to refresh, `f` to toggle fullscreen, or Escape to close.
- `/compaction-history` selects a compaction summary with the keyboard.
- Select a compaction row in the panel to read its summary.

## Clicking an indicator

Each indicator opens its own detail:

| Indicator | Opens |
| --- | --- |
| Compactions (sidebar) | The compaction history, where you pick a summary to read |
| Cache (sidebar) | Cache reuse, read and write tokens, and input coverage, with a line per session |
| Active, Model, tools (sidebar), `active` (footer) | Timing for the session and its descendants, with a line per session |
| Go allowance (sidebar), `Go 62% → 1.1h` (footer) | The Go allowance meters, their reset times, the session list price, and the console usage link |

Every dialog has a Close button. Escape closes it too, and Enter activates the button.
The session title and `/session-metrics` open the full panel.

The panel includes the selected session and recursively nested children by
default. Ancestors and siblings are excluded. The sidebar compaction count refers
only to the selected session. Completed, running, and failed compactions remain
distinct. Compaction age uses its recorded start time, not completion time.

## Cache reporting

Reported reuse is `cache.read / (input + cache.read + cache.write)`. OpenCode's
`input` is uncached input. Aggregates use token totals, not averages of percentages.
The last-request indicator disappears after a model change until the new model
reports usage. The panel also shows cache-read/write totals and input coverage.

OpenCode normalizes missing cache counters to zero. The plugin therefore hides
zero-only histories rather than claiming the provider measured 0% reuse. A mixed
history can still understate reuse when some providers omit counters. These are
reported metrics, not a cache-expiry prediction. Compaction requests are excluded
from cache percentages so the scope remains completed assistant requests.

## Timing definitions

- **Active wall time** is the union of recorded assistant-stream, tool, and
  subagent-delegation intervals across the selected scope.
- **Model wall time** runs from assistant creation until the provider stream ends.
  A completed request without that timestamp uses its completion as a fallback.
- **Tool wall time** uses tool called/completed timestamps. It can include
  permission and question waits. Subagent tools are shown as delegation waits.
- **Summed execution** adds model and non-delegation tool intervals. It can exceed
  wall time because work runs concurrently. Delegation waits are excluded to avoid
  adding parent waits to child execution.

These categories overlap and are not an additive breakdown. Earlier retry attempts
can be overwritten in OpenCode's projected records. Compaction generation lacks an
end timestamp in those records. Historical permission/question waits cannot be
reconstructed separately. Timing is therefore recorded coverage, not billing time.
Forked sessions exclude inherited messages dated before the fork's creation.

## Go allowance

OpenCode Go reports `usage.cost = 0` for requests that the subscription covers,
and OpenCode prefers the provider-reported cost over its catalog estimate. A
local proxy rewrites the reported zero to the list price, so the native cost
indicator shows the list price rather than zero.

The plugin adds the Go allowance for sessions whose model comes from the
`opencode-go` provider. It reads the workspace allowance from the server's
usage limits, which reports the share of the rolling 5-hour, weekly, and monthly
allowances that the workspace has used, plus the reset time of each window. The
sidebar shows one line, `Go 5h 5% · wk 22% · mo 11%`, above the plugin's own
metrics. Sessions on other providers are unchanged.

The window nearest its cap is the one worth watching, so the details panel lists
it first, and the compact footer line names it rather than a fixed window. The
footer reads `Go 62% → 1.1h`: the share of that window that the workspace has
used, and the time left before the window resets. A percentage without the reset
time says nothing about how much room is left, since a window that clears soon
only matters when it runs out. The reset time also identifies the window, so
the footer leaves the label out. Both turn amber at 80% and red once a window
is limited. The panel keeps the reset time on every row.

The allowance is workspace-wide, so it covers every client of the workspace, not
only the session on screen. The plugin reads it for the current location,
refreshes it every 60 seconds and when the session model changes, and coalesces
overlapping requests so that mounting several views doesn't multiply them.

The dollar figure in the details is the list price of the session's requests.
The subscription covers them, so it is a burn rate rather than a bill.

The Go provider only answers while the local cost proxy runs. The plugin probes
the proxy's health endpoint for Go sessions and shows `Go proxy down` when it
doesn't answer, so an outage doesn't look like a provider fault. The details
explain the rollback.

## Loading and options

Both `cli.base.json` alternates load this directory explicitly. Set `footer: false`
in its plugin options to disable fallback. OpenCode supplies runtime dependencies.

History and descendant discovery use paginated client calls with at most three
session loads in parallel. Partial history remains visible after a failure. Live
events are coalesced, and visible sessions reconcile every 30 seconds to recover
missed events. Completed calculations are cached between updates. No prompts or
tool output are written to plugin storage; compaction summaries stay in memory.
A failed allowance fetch keeps the last good values and never blanks the other
metrics. The details report the failure, so a first load that fails doesn't
look like a pending one.

## Tests

Pure calculation and history tests need only Bun:

```sh
mise exec bun@1.3.10 -- bun test src
```

The render test additionally needs `@opencode/plugin@2.0.25`, `@opentui/core`,
`@opentui/solid`, and `solid-js` available in a scratch directory:

```sh
mise exec bun@1.3.10 -- bun test --preload @opentui/solid/preload
```
