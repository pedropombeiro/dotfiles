import type { ReviewRequest } from "./forge"
import { reference, traitsOf } from "./forges"
import type { Lookup } from "./store"

const requests = (lookup: Lookup | undefined) => (lookup?.kind === "found" ? lookup.requests : [])

// The request's automated review, from its forge's `automatedReview` capability.
export function automatedReview(request: ReviewRequest) {
  const reviewer = traitsOf(request).automatedReview
  const status = reviewer?.status(request)
  return reviewer && status ? { name: reviewer.name, ...status } : undefined
}

export const isReviewRunning = (lookup: Lookup | undefined) =>
  requests(lookup).some((request) => automatedReview(request)?.state === "running")

// Requests whose automated review was running in `previous` and finished with
// feedback in `next`.
export function finishedReviews(previous: Lookup | undefined, next: Lookup): ReviewRequest[] {
  const running = new Set(
    requests(previous)
      .filter((request) => automatedReview(request)?.state === "running")
      .map((request) => request.url),
  )
  return requests(next).filter((request) => running.has(request.url) && automatedReview(request)?.state === "feedback")
}

const reviewer = (request: ReviewRequest) => automatedReview(request)?.name ?? "The automated reviewer"

// The one value that every request shares, or `fallback` when they differ.
const shared = (requests: ReviewRequest[], value: (request: ReviewRequest) => string, fallback: string) => {
  const values = new Set(requests.map(value))
  return values.size === 1 ? [...values][0] : fallback
}

const reviewers = (requests: ReviewRequest[]) => shared(requests, reviewer, "Automated reviewers")
const nouns = (requests: ReviewRequest[]) => shared(requests, (request) => `${traitsOf(request).noun}s`, "PRs/MRs")

// A short sentence-case outcome for notifications, such as "Requested changes".
export function reviewOutcome(request: ReviewRequest): string {
  const label = automatedReview(request)?.label ?? ""
  return label.charAt(0).toUpperCase() + label.slice(1)
}

export function reviewTitle(requests: ReviewRequest[]): string {
  if (requests.length === 1) return `${reviewer(requests[0])} finished reviewing ${reference(requests[0])}`
  return `${reviewers(requests)} finished reviewing ${requests.length} ${nouns(requests)}`
}

// Reviews that finish in the same poll share one message, so the agent
// works through them in one turn.
export function reviewMessage(requests: ReviewRequest[]): string {
  const state = (request: ReviewRequest) => `the state "${automatedReview(request)?.label ?? ""}"`
  if (requests.length === 1) {
    const [request] = requests
    const name = reviewer(request)
    return [
      `${name} finished reviewing ${reference(request)} (${request.url}) with ${state(request)}.`,
      `Fetch ${name}'s new comments and discussion threads on the ${traitsOf(request).noun}, then work through its feedback.`,
    ].join(" ")
  }
  const name = reviewers(requests)
  return [
    `${name} finished reviewing ${requests.length} ${nouns(requests)}:`,
    ...requests.map((request) => `- ${reference(request)} (${request.url}) with ${state(request)}`),
    "For each one, fetch the reviewer's new comments and discussion threads, then work through its feedback.",
  ].join("\n")
}

export function reviewToast(requests: ReviewRequest[]) {
  const outcome =
    requests.length === 1
      ? reviewOutcome(requests[0])
      : requests.map((request) => `${reference(request)}: ${automatedReview(request)?.label ?? ""}`).join(", ")
  return { title: reviewTitle(requests), message: `${outcome}. Sent to the agent.` }
}

export interface NotifiedLog {
  // Notification key to the time it was sent, in milliseconds.
  sent: Record<string, number>
}

// Other TUI instances watching the same session see the same transition, so a
// recent notification for the session and request suppresses a repeat. The
// window is shorter than a fresh review, so a later re-review still notifies.
export const NOTIFY_WINDOW = 5 * 60_000
const RETENTION = 24 * 60 * 60_000

export const notificationKey = (sessionID: string, request: ReviewRequest) => `${sessionID} ${request.url}`

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

export interface AutomatedReviewWatcherOptions {
  claim: (key: string) => boolean
  // Receives every claimed review that finished in one poll.
  send: (sessionID: string, requests: ReviewRequest[]) => void
}

// Notifies a session when automated reviews of its targets finish with feedback.
export function createAutomatedReviewWatcher(options: AutomatedReviewWatcherOptions) {
  return {
    observe(sessionID: string, previous: Lookup | undefined, next: Lookup) {
      const claimed = finishedReviews(previous, next).filter((request) => options.claim(notificationKey(sessionID, request)))
      if (claimed.length) options.send(sessionID, claimed)
    },
  }
}
