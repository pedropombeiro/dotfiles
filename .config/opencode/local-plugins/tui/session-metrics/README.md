# session-metrics

A CLI plugin for OpenCode V2 that shows compaction, cache, and timing metrics in
the sidebar. When the sidebar is hidden, a compact footer contribution shows
complete indicators that fit its allocated space. Timing disappears first, then
cache, then compaction. The native context/cost and forge indicators take priority.

## Commands

- `/session-metrics` opens a session panel. Press `c` to toggle descendants, `r`
  to refresh, `f` to toggle fullscreen, or Escape to close.
- `/compaction-history` selects a compaction summary with the keyboard.
- Select a compaction row in the panel to read its summary.

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

## Loading and options

Both `cli.base.json` alternates load this directory explicitly. Set `footer: false`
in its plugin options to disable fallback. OpenCode supplies runtime dependencies.

History and descendant discovery use paginated client calls with at most three
session loads in parallel. Partial history remains visible after a failure. Live
events are coalesced, and visible sessions reconcile every 30 seconds to recover
missed events. Completed calculations are cached between updates. No prompts or
tool output are written to plugin storage; compaction summaries stay in memory.

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
