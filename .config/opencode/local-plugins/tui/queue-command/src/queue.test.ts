import { expect, test } from "bun:test"
import { preview, queueMessage, type SessionApi } from "./queue"

const session = { type: "session", sessionID: "ses_123" }

// Records every call in order, so tests can check that the model switch
// happens before the prompt.
function recorder() {
  const calls: Array<{ method: string; request: unknown }> = []
  const api: SessionApi = {
    prompt: async (request) => void calls.push({ method: "prompt", request }),
    switchModel: async (request) => void calls.push({ method: "switchModel", request }),
  }
  return { calls, api }
}

test("queues the trimmed text and resumes the session", async () => {
  const { calls, api } = recorder()
  const toast = await queueMessage("  run the tests  ", session, api)
  expect(calls).toEqual([
    { method: "prompt", request: { sessionID: "ses_123", text: "run the tests", delivery: "queue", resume: true } },
  ])
  expect(toast).toEqual({ title: "Message queued", message: "run the tests", variant: "success" })
})

test("switches to the selected model before queueing", async () => {
  const { calls, api } = recorder()
  await queueMessage("next", session, api, { providerID: "anthropic", modelID: "claude", variant: "high" })
  expect(calls.map((call) => call.method)).toEqual(["switchModel", "prompt"])
  expect(calls[0]!.request).toEqual({
    sessionID: "ses_123",
    model: { providerID: "anthropic", id: "claude", variant: "high" },
  })
})

test("shows usage for empty input", async () => {
  const { calls, api } = recorder()
  for (const input of [undefined, "", "   "]) {
    expect((await queueMessage(input, session, api)).message).toBe("Usage: /queue <message>")
  }
  expect(calls).toHaveLength(0)
})

test("refuses outside a session", async () => {
  const { calls, api } = recorder()
  const toast = await queueMessage("hello", { type: "home" }, api, { providerID: "p", modelID: "m" })
  expect(toast.variant).toBe("warning")
  expect(calls).toHaveLength(0)
})

test("reports prompt failures", async () => {
  const { api } = recorder()
  api.prompt = async () => {
    throw new Error("boom")
  }
  const toast = await queueMessage("hello", session, api)
  expect(toast).toEqual({ message: "Could not queue the message: boom", variant: "error" })
})

test("does not queue when the model switch fails", async () => {
  const { calls, api } = recorder()
  api.switchModel = async () => {
    throw new Error("unknown model")
  }
  const toast = await queueMessage("hello", session, api, { providerID: "p", modelID: "m" })
  expect(toast).toEqual({ message: "Could not queue the message: unknown model", variant: "error" })
  expect(calls).toHaveLength(0)
})

test("preview collapses whitespace and truncates long text", () => {
  expect(preview("a\n  b")).toBe("a b")
  const long = "x".repeat(100)
  expect(preview(long)).toHaveLength(60)
  expect(preview(long).endsWith("…")).toBe(true)
})
