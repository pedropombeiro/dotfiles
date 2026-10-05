import type { OpenAction } from "./rpc"

// Shared by every plugin instance in the service, so a reply routed to another
// location's instance still settles the request.
const waiting = new Map<string, (action: OpenAction) => void>()

export function waitForReply(requestID: string, timeoutMs: number, signal?: AbortSignal): Promise<OpenAction | undefined> {
  return new Promise((resolve) => {
    const finish = (action: OpenAction | undefined) => {
      clearTimeout(timer)
      signal?.removeEventListener("abort", abort)
      waiting.delete(requestID)
      resolve(action)
    }
    const abort = () => finish(undefined)
    const timer = setTimeout(() => finish(undefined), timeoutMs)
    signal?.addEventListener("abort", abort, { once: true })
    waiting.set(requestID, finish)
  })
}

// Returns false when no request is waiting, for example after a timeout.
export function reply(requestID: string, action: OpenAction): boolean {
  const finish = waiting.get(requestID)
  if (!finish) return false
  finish(action)
  return true
}
