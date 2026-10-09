import type { MergeRequest } from "./gitlab"
import type { FeedbackNote, FeedbackSnapshot } from "./review-feedback"

// Humans add and edit comments over a review, so new comments are announced
// only after no human comment has changed for this long.
export const SETTLE_TIME = 5 * 60_000
// Feedback is fetched at most this often per session and MR, even when the
// status polls faster, such as during a Duo review.
export const FETCH_INTERVAL = 60_000
// A failed send is retried after this long instead of on every poll.
export const RETRY_DELAY = 10 * 60_000
// Records of MRs not seen for this long are dropped. The next observation
// starts a fresh baseline, so old comments are never replayed.
const RECORD_RETENTION = 30 * 24 * 60 * 60_000
// How stale a record's `seenAt` can get before an observation refreshes it.
const TOUCH_INTERVAL = 24 * 60 * 60_000
const MAX_LINKS = 20

export interface FeedbackRecord {
  // The highest note ID in the first complete snapshot. Note IDs only grow, so
  // notes at or below it predate watching, even if deleted comments later shift
  // them into the window of newest comments.
  baselineID: number
  // Note IDs already announced to the session.
  announced: string[]
  seenAt: number
}

export interface FeedbackChange {
  // Only used when the record is created.
  baselineID?: number
  announced?: string[]
}

export interface FeedbackLog {
  // Keyed by `feedbackKey`.
  records: Record<string, FeedbackRecord>
}

export const feedbackKey = (sessionID: string, mr: MergeRequest) => `${sessionID} ${mr.url}`

// Applies a change to a record, creating it if needed, and prunes stale records.
export function recordFeedback(log: FeedbackLog, key: string, change: FeedbackChange, now: number) {
  const record = (log.records[key] ??= { baselineID: change.baselineID ?? 0, announced: [], seenAt: now })
  const announced = new Set(record.announced)
  for (const id of change.announced ?? []) if (!announced.has(id)) record.announced.push(id)
  record.seenAt = now
  for (const [entry, value] of Object.entries(log.records)) {
    if (now - value.seenAt > RECORD_RETENTION) delete log.records[entry]
  }
}

export interface SeenNotes {
  baselineID: number
  announced: Set<string>
}

// The highest note ID in a snapshot, or 0 for an MR without comments.
export const baselineOf = (snapshot: FeedbackSnapshot) =>
  snapshot.notes.reduce((highest, note) => Math.max(highest, Number(note.id)), 0)

const isNew = (note: FeedbackNote, seen: SeenNotes) =>
  Number(note.id) > seen.baselineID && !seen.announced.has(note.id)

// Unresolved comments from people other than the viewer.
const humanFeedback = (snapshot: FeedbackSnapshot) =>
  snapshot.notes.filter(
    (note) => !note.system && !note.bot && note.authorID !== snapshot.viewerID && !note.resolved,
  )

// New human comments, but only once no human comment, announced or not, has
// been added or edited for SETTLE_TIME. Any activity restarts the wait for the
// whole batch, so a review in progress is announced once it goes quiet.
export function eligibleFeedback(snapshot: FeedbackSnapshot, seen: SeenNotes, now: number): FeedbackNote[] {
  const human = humanFeedback(snapshot)
  const pending = human.filter((note) => isNew(note, seen))
  if (pending.length === 0) return []
  const lastActivity = Math.max(...human.map((note) => note.editedAt))
  return now - lastActivity >= SETTLE_TIME ? pending : []
}

const authors = (notes: FeedbackNote[]) => [...new Set(notes.map((note) => `@${note.username}`))]

function list(items: string[]): string {
  if (items.length <= 2) return items.join(" and ")
  return `${items.slice(0, -1).join(", ")}, and ${items.at(-1)}`
}

export function feedbackMessage(mr: MergeRequest, notes: FeedbackNote[]): string {
  const links = notes.slice(0, MAX_LINKS).map((note) => `- @${note.username}: ${note.url}`)
  if (notes.length > MAX_LINKS) links.push(`- and ${notes.length - MAX_LINKS} more`)
  return [
    `New review feedback from ${list(authors(notes))} on !${mr.iid} (${mr.url}).`,
    "No review comment has changed for at least 5 minutes. New comments:",
    ...links,
    "Fetch these comments and their discussion threads, then assess and address the feedback.",
  ].join("\n")
}

export function feedbackToast(mr: MergeRequest, notes: FeedbackNote[]) {
  const count = notes.length === 1 ? "1 comment" : `${notes.length} comments`
  return {
    title: `New review feedback on !${mr.iid}`,
    message: `${count} from ${list(authors(notes))}. Sent to the agent.`,
  }
}

export interface FeedbackWatcherOptions {
  // The log shared with other TUI instances, which may lag behind local writes.
  log: () => FeedbackLog
  persist: (key: string, change: FeedbackChange, now: number) => void
  fetch: (sessionID: string, mr: MergeRequest) => Promise<FeedbackSnapshot | undefined>
  // Whether the MR is still the session's target, checked after each fetch.
  current: (sessionID: string, mr: MergeRequest) => boolean
  // Rejects when the session couldn't be told.
  send: (sessionID: string, mr: MergeRequest, notes: FeedbackNote[]) => Promise<void>
  onFetchError?: (error: unknown) => void
  onSendError?: (error: unknown) => void
  now?: () => number
}

export function createFeedbackWatcher(options: FeedbackWatcherOptions) {
  const now = options.now ?? Date.now
  // Local copies of records, which the shared log may not reflect yet.
  const local = new Map<string, SeenNotes>()
  const reserved = new Set<string>()
  const inflight = new Set<string>()
  const fetchedAt = new Map<string, number>()
  const retryAt = new Map<string, number>()

  // Merges the shared and local records. The higher baseline is the safer one.
  const seen = (key: string): SeenNotes | undefined => {
    const shared = options.log().records[key]
    const mine = local.get(key)
    if (!shared && !mine) return undefined
    return {
      baselineID: Math.max(shared?.baselineID ?? 0, mine?.baselineID ?? 0),
      announced: new Set([...(shared?.announced ?? []), ...(mine?.announced ?? [])]),
    }
  }

  const remember = (key: string, change: FeedbackChange, at: number) => {
    const mine = local.get(key) ?? { baselineID: change.baselineID ?? 0, announced: new Set<string>() }
    for (const id of change.announced ?? []) mine.announced.add(id)
    local.set(key, mine)
    options.persist(key, change, at)
  }

  async function observe(sessionID: string, mr: MergeRequest, snapshot: FeedbackSnapshot) {
    if (!snapshot.complete) return
    const key = feedbackKey(sessionID, mr)
    const at = now()
    const previous = seen(key)
    if (!previous) return remember(key, { baselineID: baselineOf(snapshot) }, at)
    if (at < (retryAt.get(key) ?? 0)) return
    const notes = eligibleFeedback(snapshot, previous, at).filter((note) => !reserved.has(`${key} ${note.id}`))
    if (notes.length === 0) {
      const record = options.log().records[key]
      if (record && at - record.seenAt > TOUCH_INTERVAL) options.persist(key, {}, at)
      return
    }
    const ids = notes.map((note) => note.id)
    for (const id of ids) reserved.add(`${key} ${id}`)
    try {
      await options.send(sessionID, mr, notes)
      retryAt.delete(key)
      remember(key, { announced: ids }, now())
    } catch (error) {
      retryAt.set(key, now() + RETRY_DELAY)
      options.onSendError?.(error)
    } finally {
      for (const id of ids) reserved.delete(`${key} ${id}`)
    }
  }

  return {
    // Fetches the MR's comments, unless a fetch is running or ran recently,
    // and announces settled feedback. Resolves once that work is done.
    async check(sessionID: string, mr: MergeRequest): Promise<void> {
      const key = feedbackKey(sessionID, mr)
      if (inflight.has(key) || now() - (fetchedAt.get(key) ?? -Infinity) < FETCH_INTERVAL) return
      inflight.add(key)
      fetchedAt.set(key, now())
      try {
        const snapshot = await options.fetch(sessionID, mr)
        if (!snapshot || !options.current(sessionID, mr)) return
        await observe(sessionID, mr, snapshot)
      } catch (error) {
        options.onFetchError?.(error)
      } finally {
        inflight.delete(key)
      }
    },
  }
}
