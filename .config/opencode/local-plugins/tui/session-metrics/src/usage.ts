import { duration, percent, type SegmentTone } from "./format"

// The Go subscription reports the share of the allowance that the workspace has
// used, per window. The API only publishes percentages and reset times.
export interface Meter {
  percent: number
  limited: boolean
  resetsAt: number
}

export interface Allowance {
  rolling: Meter
  weekly: Meter
  monthly: Meter
}

export interface Limits {
  workspace: { id: string; name?: string; usageURL: string }
  go?: Allowance
}

export type Severity = SegmentTone

// A meter this close to its limit deserves attention.
export const WARN_PERCENT = 80

export const METER_LABELS = { rolling: "5h", weekly: "wk", monthly: "mo" } as const

export type MeterKey = keyof Allowance

export const METER_ROWS: readonly (readonly [MeterKey, string])[] = [
  ["rolling", "Rolling 5 hours"],
  ["weekly", "Weekly"],
  ["monthly", "Monthly"],
]

export const ALLOWANCE_NOTE =
  "The allowance is the share of the Go subscription that the workspace has used. The dollar figure is the list price of the session's requests, which the subscription covers, so it is a burn rate rather than a bill."

export const PROXY_URL = "http://127.0.0.1:47990"

// The server answers the allowance quickly, and the proxy health check even
// faster. Both calls end on their own, so a stalled connection can't keep the
// last good values from being replaced.
const LIMITS_TIMEOUT_MS = 10_000
const PROXY_TIMEOUT_MS = 5_000

// Where the allowance came from. The plugin needs to tell a first load from a
// failed one, because a failed load keeps the last good values.
export type UsageStatus = "idle" | "loading" | "ready" | "empty" | "failed"

// Combines the plugin's abort signal with a timeout.
function withTimeout(signal: AbortSignal | undefined, ms: number): AbortSignal | undefined {
  if (typeof AbortSignal.timeout !== "function") return signal
  const timeout = AbortSignal.timeout(ms)
  if (!signal) return timeout
  if (typeof AbortSignal.any !== "function") return timeout
  return AbortSignal.any([signal, timeout])
}

// The client shape the plugin needs. Older servers don't expose the operation.
export interface UsageClient {
  experimental?: {
    usage?: {
      limits?: (
        input?: { location?: { directory?: string } },
        options?: { signal?: AbortSignal },
      ) => Promise<{ data?: unknown }>
    }
  }
}

function parseMeter(value: unknown): Meter | undefined {
  if (!value || typeof value !== "object") return undefined
  const record = value as Record<string, unknown>
  if (typeof record.percent !== "number" || !Number.isFinite(record.percent)) return undefined
  const resetsAt = typeof record.resetsAt === "number" && Number.isFinite(record.resetsAt) ? record.resetsAt : 0
  return { percent: record.percent, limited: record.limited === true, resetsAt }
}

export function parseLimits(payload: unknown): Limits | undefined {
  if (!payload || typeof payload !== "object") return undefined
  const data = payload as Record<string, unknown>
  const workspace = data.workspace
  if (!workspace || typeof workspace !== "object") return undefined
  const workspaceRecord = workspace as Record<string, unknown>
  const usageURL = typeof workspaceRecord.usageURL === "string" ? workspaceRecord.usageURL : ""
  const go = data.go
  let allowance: Allowance | undefined
  if (go && typeof go === "object") {
    const goRecord = go as Record<string, unknown>
    const rolling = parseMeter(goRecord.rolling)
    const weekly = parseMeter(goRecord.weekly)
    const monthly = parseMeter(goRecord.monthly)
    if (rolling && weekly && monthly) allowance = { rolling, weekly, monthly }
  }
  return {
    workspace: {
      id: typeof workspaceRecord.id === "string" ? workspaceRecord.id : "",
      name: typeof workspaceRecord.name === "string" ? workspaceRecord.name : undefined,
      usageURL,
    },
    go: allowance,
  }
}

export async function fetchLimits(client: unknown, directory?: string, signal?: AbortSignal, timeoutMs = LIMITS_TIMEOUT_MS): Promise<Limits | undefined> {
  const limits = (client as UsageClient)?.experimental?.usage?.limits
  if (!limits) return undefined
  const response = await limits(directory ? { location: { directory } } : undefined, { signal: withTimeout(signal, timeoutMs) })
  return parseLimits(response?.data)
}

// A stopped proxy fails every Go request, so the sidebar warns about it.
export async function probeProxy(signal?: AbortSignal, timeoutMs = PROXY_TIMEOUT_MS): Promise<boolean> {
  try {
    const response = await fetch(`${PROXY_URL}/healthz`, { signal: withTimeout(signal, timeoutMs) })
    return response.ok
  } catch {
    return false
  }
}

export function severity(meter: Meter): Severity {
  if (meter.limited) return "error"
  if (meter.percent >= WARN_PERCENT) return "warn"
  return "normal"
}

// The milliseconds left on a window, or undefined when the API reports no
// reset time.
function remaining(meter: Meter, now: number): number | undefined {
  if (!meter.resetsAt) return undefined
  return meter.resetsAt - now
}

export function allowanceText(allowance: Allowance): string {
  return `Go ${METER_LABELS.rolling} ${percent(allowance.rolling.percent)} · ${METER_LABELS.weekly} ${percent(allowance.weekly.percent)} · ${METER_LABELS.monthly} ${percent(allowance.monthly.percent)}`
}

// The window nearest its cap, which is the one worth watching.
export function nearestCap(allowance: Allowance): [MeterKey, Meter] {
  const [key, , meter] = metersByUrgency(allowance)[0]
  return [key, meter]
}

// The time left on a window, for the compact footer.
export function resetDuration(meter: Meter, now: number): string {
  const left = remaining(meter, now)
  if (left === undefined) return "unknown"
  if (left <= 0) return "due"
  return duration(left)
}

export function compactAllowanceText(allowance: Allowance, now: number): string {
  const [, meter] = nearestCap(allowance)
  return `Go ${percent(meter.percent)} → ${resetDuration(meter, now)}`
}

export function resetText(meter: Meter, now: number): string {
  const left = remaining(meter, now)
  if (left === undefined) return "reset time unknown"
  if (left <= 0) return "reset due"
  return `resets in ${duration(left)}`
}

// The window nearest its cap leads the panel, so the limit that needs
// attention comes first.
export function metersByUrgency(allowance: Allowance): [MeterKey, string, Meter][] {
  return METER_ROWS
    .map(([key, title]) => [key, title, allowance[key]] as [MeterKey, string, Meter])
    .toSorted((a, b) => b[2].percent - a[2].percent)
}
