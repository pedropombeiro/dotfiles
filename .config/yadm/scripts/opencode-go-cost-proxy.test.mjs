import { test } from "node:test"
import assert from "node:assert/strict"
import http from "node:http"
import { createServer, rewriteFrame, rewriteUsage } from "./opencode-go-cost-proxy.mjs"

// The retry waits for real in production, and the tests skip the waiting.
const FAST_RETRY = { retries: 3, retryDelaysMs: [0, 0, 0], sleep: () => Promise.resolve() }

// Runs a stub upstream and the proxy in front of it, then hands the ports to
// the test body.
async function withProxy(handler, run, options = {}) {
  const upstream = http.createServer(handler)
  await new Promise((resolve) => upstream.listen(0, "127.0.0.1", resolve))
  const upstreamPort = upstream.address().port
  const proxy = createServer({
    upstream: "https://upstream.test",
    fetchImpl: (url, init) => fetch(url.replace("https://upstream.test", `http://127.0.0.1:${upstreamPort}`), init),
    ...FAST_RETRY,
    ...options,
  })
  await new Promise((resolve) => proxy.listen(0, "127.0.0.1", resolve))
  const proxyPort = proxy.address().port
  try {
    await run({ proxyPort, upstreamPort })
  } finally {
    proxy.closeAllConnections()
    upstream.closeAllConnections()
    await new Promise((resolve) => proxy.close(resolve))
    await new Promise((resolve) => upstream.close(resolve))
  }
}

test("a zero cost becomes the reported list price", () => {
  const payload = { usage: { cost: 0, opencode: { list_cost: 0.00000618 } } }
  assert.equal(rewriteUsage(payload).usage.cost, 0.00000618)
})

test("a reported charge survives untouched", () => {
  const payload = { usage: { cost: 0.42, opencode: { list_cost: 0.00000618 } } }
  assert.equal(rewriteUsage(payload).usage.cost, 0.42)
})

test("a missing cost stays missing", () => {
  const payload = { usage: { opencode: { list_cost: 0.00000618 } } }
  assert.equal(rewriteUsage(payload).usage.cost, undefined)
})

test("a zero cost without a list price falls back to the catalog", () => {
  const payload = { usage: { cost: 0 } }
  assert.equal("cost" in rewriteUsage(payload).usage, false)
})

test("a payload without usage passes through", () => {
  const payload = { id: "chatcmpl-1" }
  assert.deepEqual(rewriteUsage(payload), { id: "chatcmpl-1" })
})

test("a stream frame rewrites its usage", () => {
  const frame = rewriteFrame('data: {"usage":{"cost":0,"opencode":{"list_cost":0.25}}}')
  assert.equal(frame, 'data: {"usage":{"cost":0.25,"opencode":{"list_cost":0.25}}}')
})

test("a frame with several data lines is rewritten", () => {
  const frame = rewriteFrame('data: {"usage":{"cost":0,\ndata: "opencode":{"list_cost":3}}}')
  assert.equal(frame, 'data: {"usage":{"cost":3,"opencode":{"list_cost":3}}}')
})

test("the done sentinel passes through", () => {
  assert.equal(rewriteFrame("data: [DONE]"), "data: [DONE]")
})

test("a frame without JSON passes through", () => {
  assert.equal(rewriteFrame("event: ping"), "event: ping")
})

test("the health endpoint answers without an upstream call", async () => {
  await withProxy(
    (_req, res) => {
      res.writeHead(500)
      res.end("unreachable")
    },
    async ({ proxyPort }) => {
      const response = await fetch(`http://127.0.0.1:${proxyPort}/healthz`)
      assert.equal(response.status, 200)
      assert.deepEqual(await response.json(), { status: "ok" })
    },
  )
})

test("a JSON response is rewritten on the way out", async () => {
  await withProxy(
    (_req, res) => {
      res.writeHead(200, { "content-type": "application/json" })
      res.end(JSON.stringify({ usage: { cost: 0, opencode: { list_cost: 1.5 } } }))
    },
    async ({ proxyPort }) => {
      const response = await fetch(`http://127.0.0.1:${proxyPort}/openai/v1/chat/completions`, { method: "POST", body: "{}" })
      const payload = await response.json()
      assert.equal(payload.usage.cost, 1.5)
    },
  )
})

test("a streamed response is rewritten frame by frame", async () => {
  await withProxy(
    (_req, res) => {
      res.writeHead(200, { "content-type": "text/event-stream" })
      res.write('data: {"usage":{"cost":0,"opencode":{"list_cost":2}}}\n\n')
      res.write("data: [DONE]\n\n")
      res.end()
    },
    async ({ proxyPort }) => {
      const response = await fetch(`http://127.0.0.1:${proxyPort}/openai/v1/chat/completions`, { method: "POST", body: "{}" })
      const text = await response.text()
      assert.match(text, /"cost":2/)
      assert.match(text, /data: \[DONE\]/)
    },
  )
})

test("a stream separated by carriage returns is rewritten", async () => {
  await withProxy(
    (_req, res) => {
      res.writeHead(200, { "content-type": "text/event-stream" })
      res.write('data: {"usage":{"cost":0,"opencode":{"list_cost":4}}}\r\r')
      res.end()
    },
    async ({ proxyPort }) => {
      const response = await fetch(`http://127.0.0.1:${proxyPort}/openai/v1/chat/completions`, { method: "POST", body: "{}" })
      const text = await response.text()
      assert.match(text, /"cost":4/)
    },
  )
})

test("a client error keeps its status and body without a retry", async () => {
  let calls = 0
  await withProxy(
    (_req, res) => {
      calls += 1
      res.writeHead(400, { "content-type": "application/json" })
      res.end(JSON.stringify({ error: { message: "bad request" } }))
    },
    async ({ proxyPort }) => {
      const response = await fetch(`http://127.0.0.1:${proxyPort}/openai/v1/chat/completions`, { method: "POST", body: "{}" })
      assert.equal(response.status, 400)
      assert.deepEqual((await response.json()).error, { message: "bad request" })
      assert.equal(calls, 1)
    },
  )
})

test("a temporary upstream failure is retried", async () => {
  let calls = 0
  await withProxy(
    (_req, res) => {
      calls += 1
      if (calls === 1) {
        res.writeHead(503, { "content-type": "application/json" })
        res.end(JSON.stringify({ error: { message: "try later" } }))
        return
      }
      res.writeHead(200, { "content-type": "application/json" })
      res.end(JSON.stringify({ usage: { cost: 0, opencode: { list_cost: 5 } } }))
    },
    async ({ proxyPort }) => {
      const response = await fetch(`http://127.0.0.1:${proxyPort}/openai/v1/chat/completions`, { method: "POST", body: "{}" })
      assert.equal(response.status, 200)
      assert.equal((await response.json()).usage.cost, 5)
      assert.equal(calls, 2)
    },
  )
})

test("a request that never reaches the upstream is retried", async () => {
  let calls = 0
  await withProxy(
    (_req, res) => {
      res.writeHead(200, { "content-type": "application/json" })
      res.end("{}")
    },
    async ({ proxyPort }) => {
      const proxy = createServer({
        upstream: "https://upstream.test",
        fetchImpl: () => {
          calls += 1
          return Promise.reject(Object.assign(new TypeError("fetch failed"), { cause: { code: "ENETDOWN" } }))
        },
        ...FAST_RETRY,
      })
      await new Promise((resolve) => proxy.listen(0, "127.0.0.1", resolve))
      try {
        const response = await fetch(`http://127.0.0.1:${proxy.address().port}/openai/v1/chat/completions`, {
          method: "POST",
          body: "{}",
        })
        assert.equal(response.status, 502)
        assert.equal(calls, 4)
      } finally {
        proxy.closeAllConnections()
        await new Promise((resolve) => proxy.close(resolve))
      }
    },
  )
})

test("a request that never reaches the upstream gives up after the retries", async () => {
  const proxy = createServer({
    upstream: "http://127.0.0.1:1",
    fetchImpl: () => Promise.reject(new Error("connection refused")),
    ...FAST_RETRY,
  })
  await new Promise((resolve) => proxy.listen(0, "127.0.0.1", resolve))
  const proxyPort = proxy.address().port
  try {
    const response = await fetch(`http://127.0.0.1:${proxyPort}/openai/v1/chat/completions`, { method: "POST", body: "{}" })
    assert.equal(response.status, 502)
  } finally {
    proxy.closeAllConnections()
    await new Promise((resolve) => proxy.close(resolve))
  }
})

test("a request is not retried once the client goes away", async () => {
  let calls = 0
  const controller = new AbortController()
  const proxy = createServer({
    upstream: "https://upstream.test",
    fetchImpl: (_url, init) => {
      calls += 1
      return new Promise((_resolve, reject) => {
        init.signal.addEventListener("abort", () => reject(Object.assign(new Error("aborted"), { name: "AbortError" })))
      })
    },
    ...FAST_RETRY,
  })
  await new Promise((resolve) => proxy.listen(0, "127.0.0.1", resolve))
  try {
    const request = fetch(`http://127.0.0.1:${proxy.address().port}/openai/v1/chat/completions`, {
      method: "POST",
      body: "{}",
      signal: controller.signal,
    })
    await new Promise((resolve) => setTimeout(resolve, 50))
    controller.abort()
    await assert.rejects(() => request)
    await new Promise((resolve) => setTimeout(resolve, 50))
    assert.equal(calls, 1)
  } finally {
    proxy.closeAllConnections()
    await new Promise((resolve) => proxy.close(resolve))
  }
})

test("a busy port does not take the proxy down", async () => {
  const first = createServer()
  await new Promise((resolve) => first.listen(0, "127.0.0.1", resolve))
  const port = first.address().port
  const second = createServer()
  const error = await new Promise((resolve) => {
    second.once("error", resolve)
    second.listen(port, "127.0.0.1")
  })
  assert.equal(error.code, "EADDRINUSE")
  first.closeAllConnections()
  await new Promise((resolve) => first.close(resolve))
})
test("a non-JSON body passes through unchanged", async () => {
  await withProxy(
    (_req, res) => {
      res.writeHead(200, { "content-type": "text/plain" })
      res.end("plain text")
    },
    async ({ proxyPort }) => {
      const response = await fetch(`http://127.0.0.1:${proxyPort}/openai/v1/chat/completions`, { method: "POST", body: "{}" })
      assert.equal(await response.text(), "plain text")
    },
  )
})

test("a client that goes away cancels the upstream request", async () => {
  let upstreamClosed = false
  let upstreamResponse
  const upstream = http.createServer((_req, res) => {
    upstreamResponse = res
    res.on("close", () => {
      upstreamClosed = true
    })
    res.writeHead(200, { "content-type": "text/event-stream" })
    res.write('data: {"choices":[]}\n\n')
  })
  await new Promise((resolve) => upstream.listen(0, "127.0.0.1", resolve))
  const upstreamPort = upstream.address().port
  const proxy = createServer({
    upstream: "https://upstream.test",
    fetchImpl: (url, init) => fetch(url.replace("https://upstream.test", `http://127.0.0.1:${upstreamPort}`), init),
  })
  await new Promise((resolve) => proxy.listen(0, "127.0.0.1", resolve))
  const controller = new AbortController()
  try {
    const response = await fetch(`http://127.0.0.1:${proxy.address().port}/openai/v1/chat/completions`, {
      method: "POST",
      body: "{}",
      signal: controller.signal,
    })
    await response.body.getReader().read()
    controller.abort()
    const deadline = Date.now() + 5000
    while (!upstreamClosed && Date.now() < deadline) await new Promise((resolve) => setTimeout(resolve, 25))
    assert.equal(upstreamClosed, true)
  } finally {
    upstreamResponse?.destroy()
    controller.abort()
    proxy.closeAllConnections()
    upstream.closeAllConnections()
    await new Promise((resolve) => proxy.close(resolve))
    await new Promise((resolve) => upstream.close(resolve))
  }
})

test("a broken stream drops the connection instead of ending it cleanly", async () => {
  await withProxy(
    (_req, res) => {
      res.writeHead(200, { "content-type": "text/event-stream" })
      res.write('data: {"choices":[]}\n\n')
      setTimeout(() => res.socket?.destroy(), 20)
    },
    async ({ proxyPort }) => {
      const response = await fetch(`http://127.0.0.1:${proxyPort}/openai/v1/chat/completions`, { method: "POST", body: "{}" })
      await assert.rejects(() => response.text())
    },
  )
})

test("an oversized request becomes a bad request", async () => {
  const proxy = createServer({
    upstream: "https://upstream.test",
    fetchImpl: () => Promise.reject(new Error("the upstream must not be called")),
    maxBodyBytes: 16,
  })
  await new Promise((resolve) => proxy.listen(0, "127.0.0.1", resolve))
  const proxyPort = proxy.address().port
  try {
    const response = await fetch(`http://127.0.0.1:${proxyPort}/openai/v1/chat/completions`, { method: "POST", body: "x".repeat(256) })
    assert.equal(response.status, 413)
    assert.deepEqual(await response.json(), { error: "request body too large" })
  } finally {
    proxy.closeAllConnections()
    await new Promise((resolve) => proxy.close(resolve))
  }
})

test("the request headers reach the upstream without the hop headers", async () => {
  await withProxy(
    (req, res) => {
      res.writeHead(200, { "content-type": "application/json" })
      res.end(JSON.stringify({ headers: req.headers }))
    },
    async ({ proxyPort }) => {
      const response = await fetch(`http://127.0.0.1:${proxyPort}/openai/v1/chat/completions`, {
        method: "POST",
        headers: { authorization: "Bearer token", "x-opencode-org-id": "org", "x-opencode-session": "ses" },
        body: "{}",
      })
      const { headers } = await response.json()
      assert.equal(headers.authorization, "Bearer token")
      assert.equal(headers["x-opencode-org-id"], "org")
      assert.equal(headers["x-opencode-session"], "ses")
      assert.equal(headers["accept-encoding"], "identity")
    },
  )
})

test("the path and query reach the upstream unchanged", async () => {
  await withProxy(
    (req, res) => {
      res.writeHead(200, { "content-type": "application/json" })
      res.end(JSON.stringify({ url: req.url }))
    },
    async ({ proxyPort }) => {
      const response = await fetch(`http://127.0.0.1:${proxyPort}/openai/v1/chat/completions?stream=true`)
      const { url } = await response.json()
      assert.equal(url, "/openai/v1/chat/completions?stream=true")
    },
  )
})
