import type { measure } from "./metrics"

export const duration = (ms: number) => ms >= 3_600_000 ? `${(ms / 3_600_000).toFixed(1)}h` : ms >= 60_000 ? `${Math.floor(ms / 60_000)}m` : `${Math.floor(ms / 1000)}s`
export const percent = (value: number | undefined) => value === undefined ? "unavailable" : `${value.toFixed(0)}%`

export function segments(value: ReturnType<typeof measure>, active: number) {
  const compact = value.compactions.at(-1)
  const items: string[] = []
  if (compact?.status === "running") items.push("compacting")
  else if (compact?.status === "failed") items.push("compact failed")
  else if (value.completed.length) items.push(`compact ${value.completed.length}`)
  if (value.latest?.percent !== undefined) items.push(`cache ${percent(value.latest.percent)}`)
  if (active >= 1000) items.push(`active ${duration(active)}`)
  return items
}

export function fit(items: readonly string[], width: number) {
  const output = [...items]
  while (output.length && Bun.stringWidth(output.join(" · ")) > width) output.pop()
  return output.join(" · ")
}
