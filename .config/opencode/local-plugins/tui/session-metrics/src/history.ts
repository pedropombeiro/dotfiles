import type { Message, Session } from "./metrics"

interface Page<T> { data: T[]; cursor: { next?: string | null } }
export interface Source {
  messages(id: string, cursor?: string): Promise<Page<Message>>
  children(id: string, cursor?: string): Promise<Page<Session>>
  session(id: string): Promise<Session>
}
export interface Entry {
  session?: Session
  records: Map<string, Message>
  complete: boolean
  loading: boolean
  error?: string
}

export function history(source: Source, changed: () => void) {
  const entries = new Map<string, Entry>()
  const flights = new Map<string, Promise<void>>()
  const pending = new Set<string>()
  let stopped = false
  const get = (id: string): Entry => {
    let entry = entries.get(id)
    if (!entry) {
      entry = { records: new Map(), complete: false, loading: false }
      entries.set(id, entry)
    }
    return entry
  }
  async function load(id: string) {
    if (stopped) return
    if (flights.has(id)) { pending.add(id); return flights.get(id) }
    const entry = get(id)
    const valid = () => !stopped && entries.get(id) === entry
    entry.loading = true
    changed()
    const task = (async () => {
      entry.session = await source.session(id)
      let cursor: string | undefined
      const seen = new Set<string>()
      for (let page = 0; page < 1000 && !stopped; page++) {
        const result = await source.messages(id, cursor)
        if (!valid()) return
        const known = entry.complete && result.data.some((message) => entry.records.has(message.id))
        for (const message of result.data) entry.records.set(message.id, project(message))
        if (valid()) changed()
        if (known || !result.cursor.next) { entry.complete = true; break }
        if (seen.has(result.cursor.next)) throw new Error("Repeated message pagination cursor")
        seen.add(result.cursor.next)
        cursor = result.cursor.next
      }
      if (!entry.complete && !stopped) throw new Error("Message history exceeds the pagination limit")
      entry.error = undefined
    })().catch((error: unknown) => {
      if (valid()) entry.error = error instanceof Error ? error.message : String(error)
    }).finally(() => {
      entry.loading = false
      flights.delete(id)
      if (valid()) changed()
      if (pending.delete(id) && !stopped) void load(id)
    })
    flights.set(id, task)
    return task
  }
  async function tree(root: string) {
    const queue = [root]
    const seen = new Set<string>()
    while (queue.length && !stopped) {
      const batch = queue.splice(0, 3).filter((id) => !seen.has(id))
      await Promise.all(batch.map(async (id) => {
        seen.add(id)
        await load(id)
        let cursor: string | undefined
        const cursors = new Set<string>()
        for (let page = 0; page < 1000 && !stopped; page++) {
          const result = await source.children(id, cursor)
          for (const session of result.data) {
            get(session.id).session = session
            if (!seen.has(session.id)) queue.push(session.id)
          }
          if (!result.cursor.next) break
          if (cursors.has(result.cursor.next)) throw new Error("Repeated child pagination cursor")
          cursors.add(result.cursor.next)
          cursor = result.cursor.next
          if (page === 999) throw new Error("Child inventory exceeds the pagination limit")
        }
      }))
    }
  }
  const project = (message: Message): Message => ({
    id: message.id, type: message.type, time: message.time, model: message.model,
    tokens: message.tokens, status: message.status, reason: message.reason,
    summary: message.summary, error: message.error, retry: message.retry,
    content: message.content?.filter((part) => part.type === "tool").map((part) => ({
      type: part.type, id: part.id, name: part.name, time: part.time,
      state: { status: (part.state as { status?: string } | undefined)?.status ?? "unknown" },
    })),
  })
  return {
    get, load, tree,
    entries: () => [...entries.entries()],
    overlay(id: string, records: readonly Message[]) {
      const entry = get(id)
      for (const record of records) entry.records.set(record.id, project(record))
      if (!stopped) changed()
    },
    reset(id: string) { entries.delete(id); if (flights.has(id)) pending.add(id) },
    dispose() { stopped = true; pending.clear() },
  }
}
