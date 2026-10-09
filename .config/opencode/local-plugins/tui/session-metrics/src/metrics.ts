export interface Tokens {
  input: number
  cache: { read: number; write: number }
}

export interface Message {
  id: string
  type: string
  time: { created: number; streamed?: number; completed?: number }
  model?: { providerID: string; id: string }
  tokens?: Tokens
  status?: string
  reason?: string
  summary?: string
  error?: { message: string }
  retry?: unknown
  content?: Array<{
    type: string
    id?: string
    name?: string
    time?: { created: number; ran?: number; completed?: number }
    state?: unknown
  }>
}

export interface Session {
  id: string
  parentID?: string
  title?: string
  model?: { providerID: string; id: string }
  fork?: { sessionID: string; boundary: { type: string; messageID: string } }
  time: { created: number }
}

export type Interval = readonly [number, number]

export function union(intervals: readonly Interval[]): number {
  const sorted = intervals.filter(([start, end]) => Number.isFinite(start) && Number.isFinite(end) && end > start).toSorted((a, b) => a[0] - b[0])
  let end = -Infinity
  let total = 0
  for (const [start, stop] of sorted) {
    total += Math.max(0, stop - Math.max(start, end))
    end = Math.max(end, stop)
  }
  return total
}

export function descendants(root: string, sessions: readonly Session[]): string[] {
  const ids = new Set([root])
  for (let changed = true; changed;) {
    changed = false
    for (const session of sessions) {
      if (session.parentID && ids.has(session.parentID) && !ids.has(session.id)) {
        ids.add(session.id)
        changed = true
      }
    }
  }
  return [...ids]
}

export function owned(session: Session, messages: readonly Message[]): Message[] {
  const sorted = [...new Map(messages.map((message) => [message.id, message])).values()].toSorted((a, b) => a.time.created - b.time.created || a.id.localeCompare(b.id))
  if (!session.fork) return sorted
  // Fork projections can copy messages under fresh IDs. Their original times
  // precede creation of the new session, unlike newly executed requests.
  return sorted.filter((message) => message.time.created >= session.time.created)
}

export function cache(messages: readonly Message[]) {
  const requests = messages.filter((message) => message.type === "assistant" && message.time.completed !== undefined)
  let input = 0
  let read = 0
  let write = 0
  let reported = 0
  for (const message of requests) {
    const tokens = message.tokens
    if (!tokens) continue
    const total = tokens.input + tokens.cache.read + tokens.cache.write
    if (!Number.isFinite(total) || total <= 0) continue
    input += total
    read += tokens.cache.read
    write += tokens.cache.write
    reported++
  }
  // OpenCode normalizes missing cache counters to zero, so a zero-only
  // history cannot prove that the provider supports cache reporting.
  return { input, read, write, reported, requests: requests.length, percent: read + write > 0 && input > 0 ? read / input * 100 : undefined }
}

export function measure(session: Session, messages: readonly Message[], now: number, running: boolean) {
  const records = owned(session, messages)
  const model: Interval[] = []
  const tools: Interval[] = []
  const delegates: Interval[] = []
  let partial = false
  for (const message of records) {
    if (message.type !== "assistant") continue
    const stop = message.time.streamed ?? message.time.completed ?? (running && !message.retry ? now : undefined)
    if (stop !== undefined) model.push([message.time.created, stop])
    if (message.retry || message.error || (message.time.completed !== undefined && message.time.streamed === undefined)) partial = true
    for (const tool of message.content ?? []) {
      if (tool.type !== "tool" || tool.time?.ran === undefined) continue
      const end = tool.time.completed ?? (running && (tool.state as { status?: string } | undefined)?.status === "running" ? now : undefined)
      if (end === undefined) { partial = true; continue }
      const interval: Interval = [tool.time.ran, end]
      if (tool.name === "subagent") delegates.push(interval)
      else tools.push(interval)
    }
  }
  const compact = records.filter((message) => message.type === "compaction")
  const latest = records.filter((message) => message.type === "assistant" && message.time.completed !== undefined).at(-1)
  const matches = !session.model || (latest?.model?.id === session.model.id && latest.model.providerID === session.model.providerID)
  return {
    session, records, model, tools, delegates, partial,
    active: union([...model, ...tools, ...delegates]),
    modelTime: union(model), toolTime: union(tools), delegateTime: union(delegates),
    compactions: compact, completed: compact.filter((message) => message.status === "completed"),
    cache: cache(records), latest: matches && latest ? cache([latest]) : undefined,
  }
}

export function aggregate(values: ReturnType<typeof measure>[]) {
  const models = values.flatMap((value) => value.model)
  const tools = values.flatMap((value) => value.tools)
  const delegates = values.flatMap((value) => value.delegates)
  return {
    active: union([...models, ...tools, ...delegates]),
    modelTime: union(models), toolTime: union(tools), delegateTime: union(delegates),
    // Delegation tools wait for child work, and are deliberately excluded here.
    summed: models.concat(tools).reduce((total, [start, end]) => total + Math.max(0, end - start), 0),
    cache: cache(values.flatMap((value) => value.records)),
    compactions: values.flatMap((value) => value.compactions),
  }
}
