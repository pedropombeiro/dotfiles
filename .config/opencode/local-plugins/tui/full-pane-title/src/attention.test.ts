import { expect, test } from "bun:test"
import { attentionTracker } from "./attention"

function fixture() {
  const tracker = attentionTracker((id) => id === "first" || id === "second")
  const send = (type: string, data: Record<string, unknown>) => tracker.handle({ type, data } as Parameters<typeof tracker.handle>[0])
  return { ...tracker, send }
}

test("counts permission and form requests independently, ignoring unrelated sessions", () => {
  const tracker = fixture()
  tracker.send("permission.asked", { sessionID: "other", id: "ignored" })
  expect(tracker.state()).toBeUndefined()
  tracker.send("permission.asked", { sessionID: "first", id: "same" })
  tracker.send("form.created", { form: { sessionID: "first", id: "same" } })
  tracker.send("session.status", { sessionID: "first", status: { type: "busy" } })
  expect(tracker.state()).toBe("waiting")
  tracker.send("permission.replied", { sessionID: "first", requestID: "same" })
  expect(tracker.state()).toBe("waiting")
  tracker.send("form.cancelled", { sessionID: "first", id: "same" })
  expect(tracker.state()).toBeUndefined()
})

test("keeps failures through idle and viewing until that session starts another run", () => {
  const tracker = fixture()
  tracker.send("session.execution.failed", { sessionID: "first" })
  tracker.send("session.idle", { sessionID: "first" })
  tracker.send("session.status", { sessionID: "first", status: { type: "idle" } })
  expect(tracker.state()).toBe("error")
  tracker.send("session.execution.started", { sessionID: "second" })
  expect(tracker.state()).toBe("error")
  tracker.send("session.execution.started", { sessionID: "first" })
  expect(tracker.state()).toBeUndefined()
  tracker.send("session.execution.failed", { sessionID: "first" })
  tracker.send("session.status", { sessionID: "first", status: { type: "busy" } })
  expect(tracker.state()).toBeUndefined()
})

test("waiting outranks errors and finishing clears outstanding requests", () => {
  const tracker = fixture()
  tracker.send("session.execution.failed", { sessionID: "first" })
  tracker.send("permission.asked", { sessionID: "second", id: "wait" })
  expect(tracker.state()).toBe("waiting")
  tracker.send("session.execution.succeeded", { sessionID: "second" })
  expect(tracker.state()).toBe("error")
  tracker.send("session.execution.interrupted", { sessionID: "first" })
  expect(tracker.state()).toBeUndefined()
})

test("continues tracking a conversation after it leaves the view", () => {
  let visible = true
  const tracker = attentionTracker(() => visible)
  tracker.handle({ type: "permission.asked", data: { sessionID: "first", id: "wait" } } as never)
  visible = false
  tracker.handle({ type: "permission.replied", data: { sessionID: "first", requestID: "wait" } } as never)
  expect(tracker.state()).toBeUndefined()
})
