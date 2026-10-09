import { describe, expect, test } from "bun:test"
import type { MergeRequest } from "./gitlab"
import {
  baselineOf,
  createFeedbackWatcher,
  eligibleFeedback,
  FETCH_INTERVAL,
  feedbackKey,
  feedbackMessage,
  feedbackToast,
  recordFeedback,
  RETRY_DELAY,
  SETTLE_TIME,
  type FeedbackLog,
  type SeenNotes,
} from "./human-review-watch"
import type { FeedbackNote, FeedbackSnapshot } from "./review-feedback"

const MINUTE = 60_000
const mr = { iid: "7", url: "https://gitlab.com/g/p/-/merge_requests/7" } as MergeRequest

const note = (id: string, overrides: Partial<FeedbackNote> = {}): FeedbackNote => ({
  id,
  url: `${mr.url}#note_${id}`,
  editedAt: 0,
  resolved: false,
  system: false,
  bot: false,
  authorID: "gid://gitlab/User/2",
  username: "alice",
  ...overrides,
})

const snapshot = (...notes: FeedbackNote[]): FeedbackSnapshot => ({
  complete: true,
  viewerID: "gid://gitlab/User/1",
  notes,
})

const seen = (baselineID = 0, ...announced: string[]): SeenNotes => ({ baselineID, announced: new Set(announced) })

describe("eligibleFeedback", () => {
  test("requires a comment to stay unchanged for the settle time", () => {
    const notes = snapshot(note("1", { editedAt: 0 }))
    expect(eligibleFeedback(notes, seen(), SETTLE_TIME - 1)).toEqual([])
    expect(eligibleFeedback(notes, seen(), SETTLE_TIME)).toEqual([note("1")])
  })

  test("skips baseline, announced, system, bot, own, and resolved notes", () => {
    const notes = snapshot(
      note("10"),
      note("11"),
      note("12", { system: true }),
      note("13", { bot: true }),
      note("14", { authorID: "gid://gitlab/User/1" }),
      note("15", { resolved: true }),
      note("16"),
    )
    expect(eligibleFeedback(notes, seen(10, "11"), SETTLE_TIME).map((n) => n.id)).toEqual(["16"])
  })

  test("treats notes at or below the baseline as old after deletions shift the window", () => {
    // Notes 3 and 4 predate the baseline of 9, but only now appear in the window.
    const notes = snapshot(note("3"), note("4"), note("12"))
    expect(eligibleFeedback(notes, seen(9), SETTLE_TIME).map((n) => n.id)).toEqual(["12"])
  })

  test("compares note IDs as numbers", () => {
    expect(eligibleFeedback(snapshot(note("100")), seen(99), SETTLE_TIME).map((n) => n.id)).toEqual(["100"])
  })

  test("waits until no human comment has changed for the settle time", () => {
    const notes = snapshot(note("1", { editedAt: 0 }), note("2", { editedAt: 2 * MINUTE }))
    expect(eligibleFeedback(notes, seen(), SETTLE_TIME)).toEqual([])
    expect(eligibleFeedback(notes, seen(), 2 * MINUTE + SETTLE_TIME).map((n) => n.id)).toEqual(["1", "2"])
  })

  test("counts edits to old comments as activity", () => {
    const notes = snapshot(note("1", { editedAt: 4 * MINUTE }), note("2", { editedAt: 0 }))
    expect(eligibleFeedback(notes, seen(1), SETTLE_TIME)).toEqual([])
  })

  test("ignores activity from bots, the viewer, system notes, and resolved threads", () => {
    const recent = 4 * MINUTE
    const notes = snapshot(
      note("1", { editedAt: 0 }),
      note("2", { bot: true, editedAt: recent }),
      note("3", { authorID: "gid://gitlab/User/1", editedAt: recent }),
      note("4", { system: true, editedAt: recent }),
      note("5", { resolved: true, editedAt: recent }),
    )
    expect(eligibleFeedback(notes, seen(), SETTLE_TIME).map((n) => n.id)).toEqual(["1"])
  })
})

describe("baselineOf", () => {
  test("returns the highest note ID, or 0 without notes", () => {
    expect(baselineOf(snapshot(note("9"), note("100"), note("42")))).toBe(100)
    expect(baselineOf(snapshot())).toBe(0)
  })
})

describe("recordFeedback", () => {
  test("keeps the first baseline, adds announced IDs once, and prunes old records", () => {
    const log: FeedbackLog = { records: { old: { baselineID: 1, announced: [], seenAt: 0 } } }
    const now = 31 * 24 * 60 * MINUTE
    recordFeedback(log, "k", { baselineID: 5 }, now)
    recordFeedback(log, "k", { baselineID: 8, announced: ["6", "7"] }, now)
    recordFeedback(log, "k", { announced: ["7", "9"] }, now)
    expect(log.records).toEqual({ k: { baselineID: 5, announced: ["6", "7", "9"], seenAt: now } })
  })
})

describe("feedback text", () => {
  test("names authors and links each comment", () => {
    const notes = [note("1"), note("2", { username: "bob" }), note("3")]
    const message = feedbackMessage(mr, notes)
    expect(message).toContain("New review feedback from @alice and @bob on !7")
    expect(message).toContain(`- @bob: ${mr.url}#note_2`)
    expect(feedbackToast(mr, notes)).toEqual({
      title: "New review feedback on !7",
      message: "3 comments from @alice and @bob. Sent to the agent.",
    })
    expect(feedbackToast(mr, [note("1")]).message).toBe("1 comment from @alice. Sent to the agent.")
  })

  test("lists three or more authors with commas and caps the links", () => {
    const notes = Array.from({ length: 22 }, (_, index) => note(String(index), { username: ["a", "b", "c"][index % 3] }))
    const message = feedbackMessage(mr, notes)
    expect(message).toContain("from @a, @b, and @c on")
    expect(message).toContain("- and 2 more")
  })
})

function harness(initial: FeedbackSnapshot | null = snapshot()) {
  let clock = 0
  let current = initial
  let isCurrent = true
  let fail: Error | undefined
  const log: FeedbackLog = { records: {} }
  const sent: string[][] = []
  const sendErrors: unknown[] = []
  const fetchErrors: unknown[] = []
  let fetches = 0
  const watcher = createFeedbackWatcher({
    log: () => log,
    persist: (key, change, at) => recordFeedback(log, key, change, at),
    fetch: async () => {
      fetches++
      if (current === null) throw new Error("fetch failed")
      return current
    },
    current: () => isCurrent,
    send: async (_sessionID, _mr, notes) => {
      if (fail) throw fail
      sent.push(notes.map((n) => n.id))
    },
    onSendError: (error) => sendErrors.push(error),
    onFetchError: (error) => fetchErrors.push(error),
    now: () => clock,
  })
  return {
    watcher,
    log,
    sent,
    sendErrors,
    fetchErrors,
    fetches: () => fetches,
    set: (next: FeedbackSnapshot | null) => (current = next),
    setCurrent: (value: boolean) => (isCurrent = value),
    setFail: (error: Error | undefined) => (fail = error),
    // Advances past the fetch throttle by default.
    tick: (ms = FETCH_INTERVAL) => (clock += ms),
    check: () => watcher.check("ses_1", mr),
    now: () => clock,
  }
}

describe("createFeedbackWatcher", () => {
  test("establishes a baseline on the first complete snapshot", async () => {
    const h = harness(snapshot(note("1")))
    await h.check()
    h.tick(SETTLE_TIME)
    await h.check()
    expect(h.sent).toEqual([])
    expect(h.log.records[feedbackKey("ses_1", mr)]).toMatchObject({ baselineID: 1, announced: [] })
  })

  test("doesn't announce older comments that deletions shift into the window", async () => {
    const h = harness(snapshot(note("50")))
    await h.check()
    h.set(snapshot(note("3"), note("50"), note("60")))
    h.tick(SETTLE_TIME)
    await h.check()
    expect(h.sent).toEqual([["60"]])
  })

  test("doesn't baseline from an incomplete snapshot", async () => {
    const h = harness({ ...snapshot(note("1")), complete: false })
    await h.check()
    expect(h.log.records).toEqual({})
  })

  test("announces a new comment once it has settled", async () => {
    const h = harness()
    await h.check()
    h.set(snapshot(note("1", { editedAt: h.now() })))
    h.tick(SETTLE_TIME - MINUTE)
    await h.check()
    expect(h.sent).toEqual([])
    h.tick(MINUTE)
    await h.check()
    expect(h.sent).toEqual([["1"]])
    h.tick()
    await h.check()
    expect(h.sent).toEqual([["1"]])
  })

  test("restarts the settle time after an edit", async () => {
    const h = harness()
    await h.check()
    h.set(snapshot(note("1", { editedAt: h.now() })))
    h.tick(4 * MINUTE)
    h.set(snapshot(note("1", { editedAt: h.now() })))
    h.tick(2 * MINUTE)
    await h.check()
    expect(h.sent).toEqual([])
    h.tick(3 * MINUTE)
    await h.check()
    expect(h.sent).toEqual([["1"]])
  })

  test("a newer comment delays the whole batch", async () => {
    const h = harness()
    await h.check()
    const start = h.now()
    h.tick(2 * MINUTE)
    h.set(snapshot(note("1", { editedAt: start }), note("2", { editedAt: start }), note("3", { editedAt: h.now() })))
    h.tick(3 * MINUTE)
    await h.check()
    expect(h.sent).toEqual([])
    h.tick(2 * MINUTE)
    await h.check()
    expect(h.sent).toEqual([["1", "2", "3"]])
  })

  test("an edit to an announced comment delays new ones", async () => {
    const h = harness()
    await h.check()
    h.set(snapshot(note("1")))
    h.tick(SETTLE_TIME)
    await h.check()
    expect(h.sent).toEqual([["1"]])
    h.set(snapshot(note("1", { editedAt: h.now() }), note("2", { editedAt: h.now() - SETTLE_TIME })))
    h.tick()
    await h.check()
    expect(h.sent).toEqual([["1"]])
    h.tick(SETTLE_TIME)
    await h.check()
    expect(h.sent).toEqual([["1"], ["2"]])
  })

  test("doesn't repeat announced comments after a restart", async () => {
    const h = harness()
    await h.check()
    h.set(snapshot(note("1")))
    h.tick(SETTLE_TIME)
    await h.check()
    const restarted = createFeedbackWatcher({
      log: () => h.log,
      persist: (key, change, at) => recordFeedback(h.log, key, change, at),
      fetch: async () => snapshot(note("1")),
      current: () => true,
      send: async (_sessionID, _mr, notes) => void h.sent.push(notes.map((n) => n.id)),
      now: () => h.now() + SETTLE_TIME,
    })
    await restarted.check("ses_1", mr)
    expect(h.sent).toEqual([["1"]])
  })

  test("announces comments posted while no TUI was watching", async () => {
    const h = harness()
    await h.check()
    const restarted = createFeedbackWatcher({
      log: () => h.log,
      persist: (key, change, at) => recordFeedback(h.log, key, change, at),
      fetch: async () => snapshot(note("1")),
      current: () => true,
      send: async (_sessionID, _mr, notes) => void h.sent.push(notes.map((n) => n.id)),
      now: () => SETTLE_TIME,
    })
    await restarted.check("ses_1", mr)
    expect(h.sent).toEqual([["1"]])
  })

  test("retries a failed send after a delay", async () => {
    const h = harness()
    await h.check()
    h.set(snapshot(note("1")))
    h.setFail(new Error("offline"))
    h.tick(SETTLE_TIME)
    await h.check()
    expect(h.sendErrors).toEqual([new Error("offline")])
    h.setFail(undefined)
    h.tick()
    await h.check()
    expect(h.sent).toEqual([])
    h.tick(RETRY_DELAY)
    await h.check()
    expect(h.sent).toEqual([["1"]])
  })

  test("sends a batch once when checks overlap", async () => {
    let release: () => void = () => {}
    const log: FeedbackLog = { records: { [feedbackKey("ses_1", mr)]: { baselineID: 0, announced: [], seenAt: 0 } } }
    const sent: string[][] = []
    let clock = SETTLE_TIME
    const watcher = createFeedbackWatcher({
      log: () => log,
      persist: (key, change, at) => recordFeedback(log, key, change, at),
      fetch: async () => snapshot(note("1")),
      current: () => true,
      send: (_sessionID, _mr, notes) =>
        new Promise((resolve) => {
          sent.push(notes.map((n) => n.id))
          release = resolve
        }),
      now: () => clock,
    })
    const first = watcher.check("ses_1", mr)
    await Bun.sleep(0)
    clock += FETCH_INTERVAL
    await watcher.check("ses_1", mr)
    release()
    await first
    clock += FETCH_INTERVAL
    await watcher.check("ses_1", mr)
    expect(sent).toEqual([["1"]])
  })

  test("throttles fetches", async () => {
    const h = harness()
    await h.check()
    h.tick(FETCH_INTERVAL - 1)
    await h.check()
    expect(h.fetches()).toBe(1)
    h.tick(1)
    await h.check()
    expect(h.fetches()).toBe(2)
  })

  test("drops results for an MR that is no longer the target", async () => {
    const h = harness()
    h.setCurrent(false)
    await h.check()
    expect(h.log.records).toEqual({})
  })

  test("reports fetch failures without recording anything", async () => {
    const h = harness(null)
    await h.check()
    expect(h.fetchErrors).toEqual([new Error("fetch failed")])
    expect(h.log.records).toEqual({})
  })
})
