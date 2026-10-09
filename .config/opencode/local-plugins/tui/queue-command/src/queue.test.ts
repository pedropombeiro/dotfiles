import { expect, test } from "bun:test"
import { preview, queueMessage, type PromptRequest } from "./queue"

const session = { type: "session", sessionID: "ses_123" }

function recorder() {
  const requests: PromptRequest[] = []
  return { requests, prompt: async (request: PromptRequest) => void requests.push(request) }
}

test("queues the trimmed text and resumes the session", async () => {
  const { requests, prompt } = recorder()
  const toast = await queueMessage("  run the tests  ", session, prompt)
  expect(requests).toEqual([{ sessionID: "ses_123", text: "run the tests", delivery: "queue", resume: true }])
  expect(toast).toEqual({ title: "Message queued", message: "run the tests", variant: "success" })
})

test("shows usage for empty input", async () => {
  const { requests, prompt } = recorder()
  for (const input of [undefined, "", "   "]) {
    expect((await queueMessage(input, session, prompt)).message).toBe("Usage: /queue <message>")
  }
  expect(requests).toHaveLength(0)
})

test("refuses outside a session", async () => {
  const { requests, prompt } = recorder()
  const toast = await queueMessage("hello", { type: "home" }, prompt)
  expect(toast.variant).toBe("warning")
  expect(requests).toHaveLength(0)
})

test("reports prompt failures", async () => {
  const toast = await queueMessage("hello", session, async () => {
    throw new Error("boom")
  })
  expect(toast).toEqual({ message: "Could not queue the message: boom", variant: "error" })
})

test("preview collapses whitespace and truncates long text", () => {
  expect(preview("a\n  b")).toBe("a b")
  const long = "x".repeat(100)
  expect(preview(long)).toHaveLength(60)
  expect(preview(long).endsWith("…")).toBe(true)
})
