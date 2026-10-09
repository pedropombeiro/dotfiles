import { describe, expect, test } from "bun:test"
import { aggregate, cache, descendants, measure, owned, union, type Message, type Session } from "./metrics"
import { fit, join, segments, type Segment } from "./format"

const session: Session = { id: "ses_parent", time: { created: 0 } }
const assistant = (id: string, start: number, stop: number, read = 0): Message => ({
  id, type: "assistant", time: { created: start, streamed: stop, completed: stop },
  tokens: { input: 100, cache: { read, write: 0 } },
})

describe("session metrics", () => {
  test("merges nested, parallel, adjacent, and invalid intervals", () => {
    expect(union([[10, 20], [0, 30], [15, 40], [40, 50], [70, 60], [NaN, 80]])).toBe(50)
  })
  test("selects descendants, excluding ancestors and siblings", () => {
    const sessions = [session, { ...session, id: "ses_child", parentID: session.id }, { ...session, id: "ses_grandchild", parentID: "ses_child" }, { ...session, id: "ses_sibling" }]
    expect(descendants("ses_child", sessions)).toEqual(["ses_child", "ses_grandchild"])
  })
  test("weights cache reuse by input tokens and includes writes in denominator", () => {
    const a = assistant("a", 0, 10, 900)
    const b = assistant("b", 10, 20, 0)
    b.tokens!.cache.write = 100
    expect(cache([a, b]).percent).toBe(75)
    expect(cache([b]).percent).toBe(0)
    expect(cache([assistant("c", 0, 1)]).percent).toBeUndefined()
    expect(cache([{ ...a, tokens: undefined }]).reported).toBe(0)
  })
  test("deduplicates projections and excludes inherited fork work", () => {
    const a = assistant("a", 0, 10)
    const b = assistant("b", 20, 30)
    expect(owned(session, [a, a, b])).toHaveLength(2)
    expect(owned({ ...session, time: { created: 15 }, fork: { sessionID: "ses_source", boundary: { type: "through", messageID: "a" } } }, [a, b])).toEqual([b])
  })
  test("separates streaming model time from overlapping tools", () => {
    const a = assistant("a", 0, 1000)
    a.time.completed = 3000
    a.content = [{ type: "tool", name: "shell", time: { created: 200, ran: 500, completed: 3000 } }]
    const value = measure(session, [a], 5000, false)
    expect(value.modelTime).toBe(1000)
    expect(value.toolTime).toBe(2500)
    expect(value.active).toBe(3000)
  })
  test("does not double-count child delegation in summed execution", () => {
    const a = assistant("a", 0, 1000)
    a.content = [{ type: "tool", name: "subagent", time: { created: 1000, ran: 1000, completed: 5000 } }]
    const b = assistant("b", 1000, 4000)
    const total = aggregate([measure(session, [a], 6000, false), measure({ ...session, id: "ses_child" }, [b], 6000, false)])
    expect(total.active).toBe(5000)
    expect(total.summed).toBe(4000)
    expect(total.delegateTime).toBe(4000)
  })
  test("running timers stop for idle and retry states", () => {
    const a = { ...assistant("a", 1000, 2000), time: { created: 1000 } }
    expect(measure(session, [a], 5000, true).active).toBe(4000)
    expect(measure(session, [a], 5000, false).active).toBe(0)
    expect(measure(session, [{ ...a, retry: {} }], 5000, true).active).toBe(0)
  })
  test("does not carry latest cache across model changes", () => {
    const a = { ...assistant("a", 0, 100, 100), model: { providerID: "a", id: "old" } }
    expect(measure({ ...session, model: { providerID: "a", id: "new" } }, [a], 5000, false).latest).toBeUndefined()
  })
  test("counts completed compactions separately from running and failed", () => {
    const records = ["completed", "running", "failed"].map((status, i): Message => ({ id: String(i), type: "compaction", status, reason: "auto", time: { created: i } }))
    expect(measure(session, records, 5000, false).completed).toHaveLength(1)
  })
  test("drops timing, cache, then compaction without exceeding width", () => {
    const items: Segment[] = [{ kind: "compaction", text: "compact 2" }, { kind: "cache", text: "cache 84%" }, { kind: "timing", text: "active 18m" }]
    expect(join(fit(items, 21))).toBe("compact 2 · cache 84%")
    expect(join(fit(items, 10))).toBe("compact 2")
    expect(fit(items, 10).map((item) => item.kind)).toEqual(["compaction"])
    expect(join(fit(items, 2))).toBe("")
    for (let width = 0; width < 100; width++) expect(Bun.stringWidth(join(fit(items, width)))).toBeLessThanOrEqual(width)
  })
  test("tags each indicator with the detail view it opens", () => {
    const records: Message[] = [{ id: "c", type: "compaction", status: "completed", reason: "auto", time: { created: 0 } }, assistant("a", 0, 100, 100)]
    const value = measure(session, records, 5000, false)
    expect(segments(value, 2000).map((item) => item.kind)).toEqual(["compaction", "cache", "timing"])
    expect(segments(value, 500).some((item) => item.kind === "timing")).toBe(false)
  })
})
