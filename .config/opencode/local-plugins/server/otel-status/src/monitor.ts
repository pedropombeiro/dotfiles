import { probe as defaultProbe, resolveTarget, type Probe, type Protocol } from "./probe"
import type { OtelStatus } from "./status"

export interface MonitorOptions {
  endpoint?: string
  protocol: Protocol
  intervalMs: number
  timeoutMs: number
  probe?: Probe
  now?: () => number
}

export interface Monitor {
  snapshot(): OtelStatus
  check(): Promise<OtelStatus>
  subscribe(listener: (status: OtelStatus) => void): () => void
  dispose(): void
}

export function createMonitor(options: MonitorOptions): Monitor {
  const probe = options.probe ?? defaultProbe
  const now = options.now ?? Date.now
  const target = options.endpoint ? resolveTarget(options.endpoint, options.protocol) : undefined
  const listeners = new Set<(status: OtelStatus) => void>()
  let inflight: Promise<OtelStatus> | undefined
  let disposed = false

  const base = { intervalMs: options.intervalMs, protocol: options.protocol }
  let status: OtelStatus = !options.endpoint
    ? { state: "disabled", ...base }
    : target
      ? { state: "checking", ...base, endpoint: options.endpoint }
      : {
          state: "unreachable",
          ...base,
          endpoint: options.endpoint,
          checkedAt: now(),
          error: `invalid endpoint URL for ${options.protocol}`,
        }

  function publish(next: OtelStatus): OtelStatus {
    status = next
    for (const listener of listeners) {
      try {
        listener(next)
      } catch {
        continue
      }
    }
    return next
  }

  function check(): Promise<OtelStatus> {
    if (!target || disposed) return Promise.resolve(status)
    inflight ??= probe(target, options.timeoutMs)
      .then((result) => {
        if (disposed) return status
        const next: OtelStatus = {
          state: result.ok ? "reachable" : "unreachable",
          ...base,
          endpoint: options.endpoint,
          checkedAt: now(),
          latencyMs: result.latencyMs,
        }
        if (result.error) next.error = result.error
        return publish(next)
      })
      .finally(() => {
        inflight = undefined
      })
    return inflight
  }

  let timer: ReturnType<typeof setInterval> | undefined
  if (target) {
    void check()
    timer = setInterval(() => void check(), options.intervalMs)
    timer.unref?.()
  }

  return {
    snapshot: () => status,
    check,
    subscribe(listener) {
      listeners.add(listener)
      return () => listeners.delete(listener)
    },
    dispose() {
      disposed = true
      if (timer) clearInterval(timer)
      listeners.clear()
    },
  }
}

interface SharedEntry {
  monitor: Monitor
  refs: number
}

const SHARED_KEY = Symbol.for("opencode-otel-status.monitors")

function registry(): Map<string, SharedEntry> {
  const store = globalThis as unknown as Record<symbol, Map<string, SharedEntry> | undefined>
  return (store[SHARED_KEY] ??= new Map())
}

export function acquireMonitor(options: MonitorOptions): {
  monitor: Monitor
  release: () => void
} {
  const key = JSON.stringify([options.endpoint, options.protocol, options.intervalMs, options.timeoutMs])
  const monitors = registry()
  let entry = monitors.get(key)
  if (!entry) {
    entry = { monitor: createMonitor(options), refs: 0 }
    monitors.set(key, entry)
  }
  entry.refs += 1
  const acquired = entry
  let released = false
  return {
    monitor: acquired.monitor,
    release() {
      if (released) return
      released = true
      acquired.refs -= 1
      if (acquired.refs > 0) return
      acquired.monitor.dispose()
      if (monitors.get(key) === acquired) monitors.delete(key)
    },
  }
}
