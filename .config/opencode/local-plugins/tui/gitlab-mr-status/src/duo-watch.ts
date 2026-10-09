import type { MergeRequest } from "./gitlab"
import type { Lookup } from "./store"

const REVIEWING = "REVIEW_STARTED"
// Final states that can leave feedback to act on. An approval, or a review
// that was reset to unreviewed, needs nothing from the agent. New GitLab
// states stay silent until they are added here.
const FEEDBACK_STATES = new Set(["REVIEWED", "REQUESTED_CHANGES"])

const mergeRequests = (lookup: Lookup | undefined) => (lookup?.kind === "found" ? lookup.mergeRequests : [])

export const isDuoReviewing = (lookup: Lookup | undefined) =>
  mergeRequests(lookup).some((mr) => mr.duoReviewState === REVIEWING)

// MRs whose Duo review was running in `previous` and finished with feedback in `next`.
export function finishedDuoReviews(previous: Lookup | undefined, next: Lookup): MergeRequest[] {
  const reviewing = new Set(
    mergeRequests(previous)
      .filter((mr) => mr.duoReviewState === REVIEWING)
      .map((mr) => mr.url),
  )
  return mergeRequests(next).filter(
    (mr) => reviewing.has(mr.url) && FEEDBACK_STATES.has(mr.duoReviewState ?? ""),
  )
}

const stateLabel = (mr: MergeRequest) => (mr.duoReviewState ?? "").toLowerCase().replace(/_/g, " ")

// A short sentence-case outcome for notifications, such as "Requested changes".
export function duoReviewOutcome(mr: MergeRequest): string {
  const state = stateLabel(mr)
  return state.charAt(0).toUpperCase() + state.slice(1)
}

export function duoReviewMessage(mr: MergeRequest): string {
  const state = stateLabel(mr)
  return [
    `GitLab Duo finished reviewing !${mr.iid} (${mr.url}) with the state "${state}".`,
    "Fetch Duo's new comments and discussion threads on the merge request, then work through its feedback.",
  ].join(" ")
}

export interface NotifiedLog {
  // Notification key to the time it was sent, in milliseconds.
  sent: Record<string, number>
}

// Other TUI instances watching the same session see the same transition, so a
// recent notification for the session and MR suppresses a repeat. The window
// is shorter than a fresh Duo review, so a later re-review still notifies.
export const NOTIFY_WINDOW = 5 * 60_000
const RETENTION = 24 * 60 * 60_000

export const notificationKey = (sessionID: string, mr: MergeRequest) => `${sessionID} ${mr.url}`

export const recentlyNotified = (log: NotifiedLog, key: string, now: number) =>
  now - (log.sent[key] ?? -Infinity) < NOTIFY_WINDOW

export function recordNotification(log: NotifiedLog, key: string, now: number) {
  log.sent[key] = now
  for (const [entry, at] of Object.entries(log.sent)) if (now - at > RETENTION) delete log.sent[entry]
}

export interface ClaimOptions {
  // The log shared with other TUI instances, which may lag behind local writes.
  shared: () => NotifiedLog
  persist: (key: string, now: number) => void
  now?: () => number
}

// Returns a synchronous check-and-record, so two transitions in the same tick
// can't both pass the check before either is recorded.
export function createNotificationClaim(options: ClaimOptions) {
  const now = options.now ?? Date.now
  const local: NotifiedLog = { sent: {} }
  return (key: string): boolean => {
    const at = now()
    if (recentlyNotified(local, key, at) || recentlyNotified(options.shared(), key, at)) return false
    recordNotification(local, key, at)
    options.persist(key, at)
    return true
  }
}

export interface DuoWatcherOptions {
  claim: (key: string) => boolean
  send: (sessionID: string, mr: MergeRequest) => void
}

// Notifies a session when Duo finishes reviewing its target MR with feedback.
export function createDuoWatcher(options: DuoWatcherOptions) {
  return {
    observe(sessionID: string, previous: Lookup | undefined, next: Lookup) {
      for (const mr of finishedDuoReviews(previous, next)) {
        if (options.claim(notificationKey(sessionID, mr))) options.send(sessionID, mr)
      }
    },
  }
}
