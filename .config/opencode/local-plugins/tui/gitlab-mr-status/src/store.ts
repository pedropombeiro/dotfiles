import type { Repository } from "./git"
import { GitLabError, type ErrorKind, type MergeRequest } from "./gitlab"

export type Lookup =
  | { kind: "none"; reason: string }
  // `repository` is set for branch lookups. A session target lookup sets
  // `sessionTarget` instead, a display label for where the MR came from,
  // because it ignores the checked-out branch.
  // `explicitTarget` is set only for MRs that came from set_session_target.
  | {
      kind: "found"
      repository?: Repository
      sessionTarget?: string
      explicitTarget?: boolean
      mergeRequests: MergeRequest[]
    }

export interface Snapshot {
  lookup?: Lookup
  fetchedAt?: number
  error?: { kind: ErrorKind; message: string; at: number }
  loading: boolean
}

export interface StoreOptions {
  load: (directory: string) => Promise<Lookup>
  onChange: () => void
  // Called after each successful load with the lookup it replaced.
  onLoad?: (directory: string, previous: Lookup | undefined, next: Lookup) => void
  // Receives errors thrown by `onLoad`, which would otherwise be swallowed.
  onLoadError?: (error: unknown) => void
  // Lookups that match poll at `activeInterval` instead of `interval`.
  active?: (lookup: Lookup | undefined) => boolean
  activeInterval?: number
  now?: () => number
  setTimer?: (callback: () => void, delay: number) => unknown
  clearTimer?: (timer: unknown) => void
  interval?: number
  maxBackoff?: number
  // Event-driven refreshes within this window after a fetch are skipped.
  minEventInterval?: number
}

interface Entry {
  snapshot: Snapshot
  refs: number
  failures: number
  inflight?: Promise<Snapshot>
  invalidated?: boolean
  timer?: unknown
}

export function createStatusStore(options: StoreOptions) {
  const now = options.now ?? Date.now
  const setTimer = options.setTimer ?? ((callback, delay) => setTimeout(callback, delay))
  const clearTimer = options.clearTimer ?? ((timer) => clearTimeout(timer as ReturnType<typeof setTimeout>))
  const interval = options.interval ?? 120_000
  const maxBackoff = options.maxBackoff ?? 900_000
  const minEventInterval = options.minEventInterval ?? 15_000
  const entries = new Map<string, Entry>()
  let disposed = false

  const entry = (directory: string) => {
    let value = entries.get(directory)
    if (!value) {
      value = { snapshot: { loading: false }, refs: 0, failures: 0 }
      entries.set(directory, value)
    }
    return value
  }

  const update = (value: Entry, patch: Partial<Snapshot>) => {
    value.snapshot = { ...value.snapshot, ...patch }
    if (!disposed) options.onChange()
  }

  const cancelTimer = (value: Entry) => {
    if (value.timer === undefined) return
    clearTimer(value.timer)
    value.timer = undefined
  }

  const baseInterval = (value: Entry) =>
    options.active?.(value.snapshot.lookup) ? (options.activeInterval ?? interval) : interval
  const pollDelay = (value: Entry) => Math.min(baseInterval(value) * 2 ** value.failures, maxBackoff)

  // The last load, successful or not, so failed lookups also wait out their backoff.
  const lastAttempt = (value: Entry) =>
    Math.max(value.snapshot.fetchedAt ?? -Infinity, value.snapshot.error?.at ?? -Infinity)

  const schedule = (directory: string, value: Entry, delay = pollDelay(value)) => {
    cancelTimer(value)
    if (disposed || value.refs === 0) return
    const lookup = value.snapshot.lookup
    // Without an MR there is nothing to watch; turn ends, branch changes, and
    // the command still look again.
    if (!value.snapshot.error && (lookup?.kind !== "found" || lookup.mergeRequests.length === 0)) return
    value.timer = setTimer(() => {
      value.timer = undefined
      void refresh(directory)
    }, delay)
  }

  function refresh(directory: string): Promise<Snapshot> {
    const value = entry(directory)
    if (value.inflight) return value.inflight
    update(value, { loading: true })
    value.inflight = options
      .load(directory)
      .then(
        (lookup) => {
          const previous = value.snapshot.lookup
          value.failures = 0
          update(value, { lookup, fetchedAt: now(), error: undefined, loading: false })
          // A failing callback must not leave the load in flight forever.
          try {
            if (!disposed) options.onLoad?.(directory, previous, lookup)
          } catch (error) {
            try {
              options.onLoadError?.(error)
            } catch {}
          }
        },
        (error: unknown) => {
          value.failures++
          const known = error instanceof GitLabError
          update(value, {
            loading: false,
            error: {
              kind: known ? error.kind : "request",
              message: error instanceof Error ? error.message : String(error),
              at: now(),
            },
          })
        },
      )
      .then(() => {
        value.inflight = undefined
        if (value.invalidated) {
          value.invalidated = false
          return refresh(directory)
        }
        schedule(directory, value)
        return value.snapshot
      })
    return value.inflight
  }

  return {
    get(directory: string): Snapshot {
      return entries.get(directory)?.snapshot ?? { loading: false }
    },
    acquire(directory: string): () => void {
      const value = entry(directory)
      value.refs++
      // Showing a session again, such as on a tab switch, reuses cached data
      // until the next poll would have been due, and resumes that poll schedule.
      if (value.refs === 1 && !value.inflight) {
        const remaining = lastAttempt(value) + pollDelay(value) - now()
        if (remaining <= 0) void refresh(directory)
        else schedule(directory, value, remaining)
      }
      let released = false
      return () => {
        if (released) return
        released = true
        value.refs--
        if (value.refs === 0) cancelTimer(value)
      }
    },
    refresh,
    keys(): string[] {
      return [...entries.keys()]
    },
    // Refreshes a directory that is being displayed, unless it was fetched moments ago.
    notify(directory: string) {
      const value = entries.get(directory)
      if (!value || value.refs === 0 || value.inflight) return
      const last = Math.max(value.snapshot.fetchedAt ?? 0, value.snapshot.error?.at ?? 0)
      if (now() - last < minEventInterval) return
      void refresh(directory)
    },
    // Forces a refresh after a known state change, such as a branch switch.
    invalidate(directory: string) {
      const value = entries.get(directory)
      if (!value || value.refs === 0) return
      // A load that started before the change may describe the previous branch.
      if (value.inflight) value.invalidated = true
      else void refresh(directory)
    },
    dispose() {
      disposed = true
      for (const value of entries.values()) cancelTimer(value)
      entries.clear()
    },
  }
}

export type StatusStore = ReturnType<typeof createStatusStore>
