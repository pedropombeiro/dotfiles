import { expect, test } from "bun:test"
import { history, type Source } from "./history"
import type { Message } from "./metrics"

const message = (id: string): Message => ({ id, type: "assistant", time: { created: 0 } })
const base: Source = {
  session: async (id) => ({ id, time: { created: 0 } }),
  children: async () => ({ data: [], cursor: {} }),
  messages: async () => ({ data: [], cursor: {} }),
}

test("loads full paginated history and deduplicates updates", async () => {
  const calls: Array<string | undefined> = []
  const store = history({ ...base, messages: async (_id, cursor) => {
    calls.push(cursor)
    return cursor ? { data: [message("old")], cursor: {} } : { data: [message("new")], cursor: { next: "older" } }
  } }, () => {})
  await store.load("ses_one")
  expect(calls).toEqual([undefined, "older"])
  expect(store.get("ses_one").complete).toBe(true)
  await store.load("ses_one")
  expect(calls).toHaveLength(3)
  expect(store.get("ses_one").records.size).toBe(2)
})

test("retains partial history after an error", async () => {
  const store = history({ ...base, messages: async (_id, cursor) => {
    if (cursor) throw new Error("offline")
    return { data: [message("new")], cursor: { next: "older" } }
  } }, () => {})
  await store.load("ses_one")
  expect(store.get("ses_one").complete).toBe(false)
  expect(store.get("ses_one").records.size).toBe(1)
  expect(store.get("ses_one").error).toBe("offline")
})

test("discovers nested children without ancestors or siblings", async () => {
  const store = history({ ...base, children: async (id) => ({ data: id === "ses_root" ? [{ id: "ses_child", parentID: id, time: { created: 0 } }] : [], cursor: {} }) }, () => {})
  await store.tree("ses_root")
  expect(store.entries().map(([id]) => id)).toEqual(["ses_root", "ses_child"])
})

test("detects repeated cursors", async () => {
  const store = history({ ...base, messages: async () => ({ data: [message("a")], cursor: { next: "loop" } }) }, () => {})
  await store.load("ses_one")
  expect(store.get("ses_one").error).toContain("Repeated")
})

test("stores timing metadata without assistant text or tool arguments", async () => {
  const store = history(base, () => {})
  store.overlay("ses_one", [{ ...message("a"), content: [
    { type: "text", text: "private prompt" },
    { type: "tool", name: "shell", time: { created: 0, ran: 1, completed: 2 }, state: { status: "completed", input: "private command", content: "private output" } },
  ] } as Message])
  expect(JSON.stringify([...store.get("ses_one").records.values()])).not.toContain("private")
  expect(store.get("ses_one").records.get("a")?.content).toHaveLength(1)
})
