// Keeps at most one status key polling per session. A key change, such as a
// new title prefix, moves the hold instead of polling both keys.
export function createSessionHolds(acquire: (key: string) => () => void) {
  const holds = new Map<string, { key: string; release: () => void }>()

  const release = (sessionID: string) => {
    holds.get(sessionID)?.release()
    holds.delete(sessionID)
  }

  return {
    // Holds `key` for the session when wanted, otherwise releases any hold.
    update(sessionID: string, key: string, wanted: boolean) {
      if (!wanted) return release(sessionID)
      if (holds.get(sessionID)?.key === key) return
      release(sessionID)
      holds.set(sessionID, { key, release: acquire(key) })
    },
    // Releases the session's hold only if it is on `key`.
    releaseKey(sessionID: string, key: string) {
      if (holds.get(sessionID)?.key === key) release(sessionID)
    },
    heldKeys: () => [...holds.values()].map((hold) => hold.key),
    dispose() {
      for (const sessionID of [...holds.keys()]) release(sessionID)
    },
  }
}
