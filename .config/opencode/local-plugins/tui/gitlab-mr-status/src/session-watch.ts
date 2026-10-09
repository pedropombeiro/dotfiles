import { isDuoReviewing } from "./duo-watch"
import type { MergeRequest } from "./gitlab"
import { createSessionHolds } from "./holds"
import type { Lookup } from "./store"

export interface SessionWatchOptions {
  // Keeps a status key polling; returns its release.
  acquire: (key: string) => () => void
  // Whether `key` is the session's current status key. Loads of an older key,
  // such as one from before a title change, are ignored.
  isCurrent: (key: string, sessionID: string) => boolean
  duo?: { observe: (sessionID: string, previous: Lookup | undefined, next: Lookup) => void }
  human?: { check: (sessionID: string, mr: MergeRequest) => unknown }
}

const explicitTarget = (lookup: Lookup | undefined): MergeRequest | undefined =>
  lookup?.kind === "found" && lookup.explicitTarget === true ? lookup.mergeRequests[0] : undefined

// Watches each session's set_session_target MR for Duo and human reviews, and
// keeps its status polling while either needs it, even when hidden.
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

      const mr = explicitTarget(next)
      const open = mr?.state === "opened"
      const wanted = !!mr && ((!!options.duo && isDuoReviewing(next)) || (!!options.human && open))
      holds.update(sessionID, key, wanted)
      if (!mr) return

      options.duo?.observe(sessionID, previous, next)
      if (open) options.human?.check(sessionID, mr)
    },
    // Whether the MR is still the session's target.
    isTarget(sessionID: string, mr: MergeRequest) {
      return explicitTarget(last.get(sessionID))?.url === mr.url
    },
    heldKeys: () => holds.heldKeys(),
    dispose: () => holds.dispose(),
  }
}
