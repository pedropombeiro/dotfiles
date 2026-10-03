export type OtelState = "checking" | "reachable" | "unreachable" | "disabled"

export type OtelStatus = {
  state: OtelState
  intervalMs: number
  protocol: string
  endpoint?: string
  checkedAt?: number
  latencyMs?: number
  error?: string
}

export type IndicatorState = OtelState | "unknown"

const STALE_INTERVALS = 3

export function indicatorState(status: OtelStatus | undefined, now: number): IndicatorState {
  if (!status) return "unknown"
  if (status.state !== "reachable" && status.state !== "unreachable") return status.state
  if (status.checkedAt === undefined) return "unknown"
  return now - status.checkedAt > status.intervalMs * STALE_INTERVALS ? "unknown" : status.state
}

export function indicatorLabel(state: IndicatorState): string {
  switch (state) {
    case "reachable":
    case "unreachable":
      return "● 🔭"
    case "checking":
    case "unknown":
      return "○ 🔭"
    case "disabled":
      return ""
  }
}

function describeAge(ms: number): string {
  const seconds = Math.max(0, Math.round(ms / 1000))
  if (seconds < 60) return `${seconds}s ago`
  const minutes = Math.round(seconds / 60)
  if (minutes < 60) return `${minutes}m ago`
  return `${Math.round(minutes / 60)}h ago`
}

export function describeStatus(status: OtelStatus | undefined, now: number): string {
  const state = indicatorState(status, now)
  if (!status) return "Status unavailable. Is the otel-status server plugin loaded?"
  if (state === "disabled") return "No OTEL endpoint is configured."

  const grpc = status.protocol === "grpc"
  const lines = [`Endpoint: ${status.endpoint} (${status.protocol})`, `Status: ${state}`]
  if (status.checkedAt !== undefined) {
    lines.push(`Last check: ${describeAge(now - status.checkedAt)}`)
  }
  if (status.state === "reachable" && status.latencyMs !== undefined) {
    lines.push(`${grpc ? "Connect" : "Response"} time: ${status.latencyMs}ms`)
  }
  if (status.state === "unreachable" && status.error) lines.push(`Error: ${status.error}`)
  lines.push(
    "",
    grpc
      ? "Checks TCP reachability only; it does not confirm that exports succeed."
      : "Sends an empty OTLP metrics request; it does not confirm that real exports succeed.",
  )
  return lines.join("\n")
}
