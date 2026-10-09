import type { aggregate, measure } from "./metrics"

export const duration = (ms: number) => ms >= 3_600_000 ? `${(ms / 3_600_000).toFixed(1)}h` : ms >= 60_000 ? `${Math.floor(ms / 60_000)}m` : `${Math.floor(ms / 1000)}s`
export const percent = (value: number | undefined) => value === undefined ? "unavailable" : `${value.toFixed(0)}%`

// Which detail view an indicator opens when clicked.
export type Indicator = "compaction" | "cache" | "timing"
export interface Segment { kind: Indicator; text: string }

export function segments(value: ReturnType<typeof measure>, active: number): Segment[] {
  const compact = value.compactions.at(-1)
  const items: Segment[] = []
  if (compact?.status === "running") items.push({ kind: "compaction", text: "compacting" })
  else if (compact?.status === "failed") items.push({ kind: "compaction", text: "compact failed" })
  else if (value.completed.length) items.push({ kind: "compaction", text: `compact ${value.completed.length}` })
  if (value.latest?.percent !== undefined) items.push({ kind: "cache", text: `cache ${percent(value.latest.percent)}` })
  if (active >= 1000) items.push({ kind: "timing", text: `active ${duration(active)}` })
  return items
}

export const join = (items: readonly Segment[]) => items.map((item) => item.text).join(" · ")

// Drops trailing indicators until the rest fit, so timing goes first and compaction last.
export function fit(items: readonly Segment[], width: number): Segment[] {
  const output = [...items]
  while (output.length && Bun.stringWidth(join(output)) > width) output.pop()
  return output
}

type Total = ReturnType<typeof aggregate>

export const TIMING_NOTE = "Recorded intervals, not billing time. Overlaps are merged for wall time. Summed execution excludes subagent delegation waits. Tool durations may include permission/question waits. Earlier retry attempts and compaction generation time may be absent."
export const CACHE_NOTE = "Reuse = cache reads / (uncached input + cache reads + cache writes). Providers can omit cache counters, which OpenCode normalizes to zero. Zero-only histories are unavailable; mixed-provider totals may understate reuse."

export const timingText = (total: Total) =>
  `Active wall time ${duration(total.active)}\nModel wall time ${duration(total.modelTime)}\nTool wall time ${duration(total.toolTime)}\nDelegation wait ${duration(total.delegateTime)}\nSummed execution ${duration(total.summed)}`

export const cacheText = (total: Total) =>
  `Reported cache reuse ${percent(total.cache.percent)}\nRead ${total.cache.read.toLocaleString()} · write ${total.cache.write.toLocaleString()} tokens\nInput coverage ${total.cache.reported}/${total.cache.requests} completed requests`
