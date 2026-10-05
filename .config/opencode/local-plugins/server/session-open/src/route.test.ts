import { describe, expect, test } from "bun:test"
import { openAction, showsSource } from "./route"

describe("showsSource", () => {
  const request = { sourceSessionIDs: ["ses_child", "ses_root"] }

  test("matches the requesting session or one of its ancestors", () => {
    expect(showsSource({ type: "session", sessionID: "ses_child" }, request)).toBe(true)
    expect(showsSource({ type: "session", sessionID: "ses_root" }, request)).toBe(true)
  })

  test("ignores terminals showing other sessions or pages", () => {
    expect(showsSource({ type: "session", sessionID: "ses_other" }, request)).toBe(false)
    expect(showsSource({ type: "home" }, request)).toBe(false)
  })
})

describe("openAction", () => {
  test("focuses a tab for a root session when tabs are enabled", () => {
    expect(openAction(true, { root: true })).toBe("tab")
  })

  test("navigates otherwise", () => {
    expect(openAction(true, { root: false })).toBe("route")
    expect(openAction(false, { root: true })).toBe("route")
  })
})
