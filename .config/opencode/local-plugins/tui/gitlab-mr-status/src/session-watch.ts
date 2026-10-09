import { isReviewRunning } from "./automated-review-watch"
import type { ReviewRequest } from "./forge"
import { traitsOf } from "./forges"
import { createSessionHolds } from "./holds"
import type { Lookup } from "./store"

export interface SessionWatchOptions {
  // Keeps a status key polling; returns its release.
  acquire: (key: string) => () => void
  // Whether `key` is the session's current status key. Loads of an older key,
  // such as one from before a title change, are ignored.
  isCurrent: (key: string, sessionID: string) => boolean
  automated?: { observe: (sessionID: string, previous: Lookup | undefined, next: Lookup) => void }
  human?: { check: (sessionID: string, request: ReviewRequest) => unknown }
}

const explicitTarget = (lookup: Lookup | undefined): ReviewRequest | undefined =>
  lookup?.kind === "found" && lookup.explicitTarget === true ? lookup.requests[0] : undefined

// Watches each session's set_session_target PR/MR for automated and human
// reviews, and keeps its status polling while either needs it, even when hidden.
// Each kind of notification needs the matching capability on the target's forge.
export function createSessionWatch(options: SessionWatchOptions) {
  const holds = createSessionHolds(options.acquire)
  // The last lookup per session, so a key change doesn't lose the previous state.
  const last = new Map<string, Lookup>()

  return {
    onLoad(key: string, sessionID: string | undefined, next: Lookup) {
      if (!sessionID) return
      if (!options.isCurrent(key, sessionID)) return holds.releaseKey(sessionID, key)
      const previous = last.get(sessionID)
      last.set(sessionID, next)

      const request = explicitTarget(next)
      const traits = request && traitsOf(request)
      const automated = !!options.automated && !!traits?.automatedReview
      const human = !!options.human && !!traits?.feedback && request?.state === "opened"
      holds.update(sessionID, key, (automated && isReviewRunning(next)) || human)
      if (!request) return

      if (automated) options.automated?.observe(sessionID, previous, next)
      if (human) options.human?.check(sessionID, request)
    },
    // Whether the PR/MR is still the session's target.
    isTarget(sessionID: string, request: ReviewRequest) {
      return explicitTarget(last.get(sessionID))?.url === request.url
    },
    heldKeys: () => holds.heldKeys(),
    dispose: () => holds.dispose(),
  }
}
