import { describe, expect, test } from "bun:test"
import { createSessionHolds } from "./holds"

function harness() {
  const counts = new Map<string, number>()
  const holds = createSessionHolds((key) => {
    counts.set(key, (counts.get(key) ?? 0) + 1)
    return () => counts.set(key, counts.get(key)! - 1)
  })
  const active = () => [...counts].filter(([, count]) => count > 0).map(([key]) => key)
  return { holds, active, counts }
}

describe("createSessionHolds", () => {
  test("acquires a key once while wanted and releases it when not", () => {
    const { holds, active, counts } = harness()
    holds.update("ses_1", "k1", true)
    holds.update("ses_1", "k1", true)
    expect(counts.get("k1")).toBe(1)
    holds.update("ses_1", "k1", false)
    expect(active()).toEqual([])
  })

  test("moves the hold when the session's key changes", () => {
    const { holds, active } = harness()
    holds.update("ses_1", "k1", true)
    holds.update("ses_1", "k2", true)
    expect(active()).toEqual(["k2"])
    expect(holds.heldKeys()).toEqual(["k2"])
  })

  test("releases a specific key only if it is held", () => {
    const { holds, active } = harness()
    holds.update("ses_1", "k2", true)
    holds.releaseKey("ses_1", "k1")
    expect(active()).toEqual(["k2"])
    holds.releaseKey("ses_1", "k2")
    expect(active()).toEqual([])
  })

  test("holds one key per session and releases all on dispose", () => {
    const { holds, active } = harness()
    holds.update("ses_1", "k1", true)
    holds.update("ses_2", "k2", true)
    expect(active()).toEqual(["k1", "k2"])
    holds.dispose()
    expect(active()).toEqual([])
  })
})
