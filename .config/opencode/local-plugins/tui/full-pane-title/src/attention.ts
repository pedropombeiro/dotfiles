import type { Plugin } from "@opencode/plugin/tui"

type Event = Parameters<Parameters<Plugin.Context["data"]["listen"]>[0]>[0]["details"]
export type Attention = "waiting" | "error" | undefined

export function attentionTracker(visible: (sessionID: string) => boolean) {
  const active = new Set<string>()
  const errors = new Set<string>()
  const requests = new Map<string, string>()
  const clearRequests = (sessionID: string) => {
    for (const [id, owner] of requests) if (owner === sessionID) requests.delete(id)
  }
  return {
    state(): Attention {
      return requests.size ? "waiting" : errors.size ? "error" : undefined
    },
    handle(event: Event) {
      const data = event.data
      const sessionID = event.type === "form.created" ? event.data.form.sessionID
        : "sessionID" in data && typeof data.sessionID === "string" ? data.sessionID : undefined
      if (!sessionID || !(active.has(sessionID) || errors.has(sessionID) || visible(sessionID))) return
      switch (event.type) {
        case "permission.asked":
          requests.set(`permission:${event.data.id}`, sessionID)
          active.add(sessionID)
          break
        case "form.created":
          requests.set(`form:${event.data.form.id}`, sessionID)
          active.add(sessionID)
          break
        case "permission.replied":
          if (requests.get(`permission:${event.data.requestID}`) === sessionID) {
            requests.delete(`permission:${event.data.requestID}`)
          }
          break
        case "form.replied":
        case "form.cancelled":
          if (requests.get(`form:${event.data.id}`) === sessionID) requests.delete(`form:${event.data.id}`)
          break
        case "session.execution.started":
          active.add(sessionID)
          errors.delete(sessionID)
          break
        case "session.status":
          if (event.data.status.type === "busy") {
            active.add(sessionID)
            errors.delete(sessionID)
          }
          if (event.data.status.type === "idle") {
            active.delete(sessionID)
            clearRequests(sessionID)
          }
          break
        case "session.idle":
          active.delete(sessionID)
          clearRequests(sessionID)
          break
        case "session.execution.failed":
          active.delete(sessionID)
          clearRequests(sessionID)
          errors.add(sessionID)
          break
        case "session.execution.succeeded":
        case "session.execution.interrupted":
          active.delete(sessionID)
          clearRequests(sessionID)
          errors.delete(sessionID)
          break
      }
    },
  }
}
