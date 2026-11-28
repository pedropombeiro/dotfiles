#!/usr/bin/env node
// Local proxy that gives OpenCode Go requests a list-price cost.
//
// OpenCode Go reports `usage.cost = 0` for requests that the Go subscription
// covers, and OpenCode prefers the provider-reported cost over its own catalog
// estimate. A reported zero is therefore authoritative, and every Go session
// records a cost of zero. The same payload carries the list price in
// `usage.opencode.list_cost`, so this proxy copies it into `usage.cost`.
//
// The proxy binds the loopback interface only, forwards to the public Go
// inference endpoint, and logs no headers, tokens, or prompt content.

import http from "node:http"
import { pathToFileURL } from "node:url"

const HOST = process.env.OPENCODE_GO_PROXY_HOST ?? "127.0.0.1"
const PORT = Number(process.env.OPENCODE_GO_PROXY_PORT ?? 47990)
const UPSTREAM = (process.env.OPENCODE_GO_PROXY_UPSTREAM ?? "https://opencode.ai/inference/go").replace(/\/+$/, "")
const MAX_BODY_BYTES = 64 * 1024 * 1024

// A laptop that just woke up has no network for a moment, and the upstream
// occasionally answers with a temporary error. OpenCode has no other way to
// reach the provider, so a request is retried before it is given up on.
const RETRY_DELAYS_MS = [250, 1000, 3000]
// The upstream has to send its headers within this window, so a black-holed
// connection fails instead of hanging the session forever.
const UPSTREAM_TIMEOUT_MS = 120_000

// Statuses that mean "ask again" rather than "the request is wrong".
const RETRYABLE_STATUS = new Set([408, 425, 429, 500, 502, 503, 504])

// Socket and resolver failures that a later attempt can get past.
const RETRYABLE_CODES = new Set([
  "EAI_AGAIN",
  "ECONNREFUSED",
  "ECONNRESET",
  "EHOSTUNREACH",
  "ENETUNREACH",
  "ENOTFOUND",
  "EPIPE",
  "ETIMEDOUT",
  "UND_ERR_CONNECT_TIMEOUT",
  "UND_ERR_HEADERS_TIMEOUT",
  "UND_ERR_SOCKET",
])

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

// Headers that describe the hop rather than the request.
const DROPPED_REQUEST_HEADERS = new Set([
  "host",
  "content-length",
  "accept-encoding",
  "connection",
  "keep-alive",
  "proxy-connection",
  "transfer-encoding",
  "upgrade",
])

// The proxy re-serializes rewritten bodies, so their length and encoding no
// longer match the upstream ones.
const DROPPED_RESPONSE_HEADERS = new Set([
  "content-length",
  "content-encoding",
  "transfer-encoding",
  "connection",
  "keep-alive",
])

// A blank line ends a server-sent event. Line terminators can be CRLF, LF, or
// CR, and the blank line can mix them.
const FRAME_END = /\r\n\r\n|\n\r\n|\r\n\n|\n\n|\r\r/

// Go reports `usage.cost = 0` for subscription-covered requests. The list
// price travels in the same payload, so copy it over. A reported non-zero cost
// is a real charge, which happens when Go's Extra Usage falls back to Console
// credits, and it stays untouched.
export function rewriteUsage(payload) {
  const usage = payload?.usage
  if (!usage || typeof usage !== "object") return payload
  if (usage.cost !== 0) return payload
  const listCost = usage.opencode?.list_cost
  if (typeof listCost === "number" && Number.isFinite(listCost)) {
    usage.cost = listCost
  } else {
    // No list price to report. Dropping the zero lets OpenCode fall back to
    // the catalog price for the model.
    delete usage.cost
  }
  return payload
}

// Normalizes the line endings inside a frame, so the data lines can be found
// whatever the upstream uses.
function normalizeFrame(text) {
  return text.replace(/\r\n/g, "\n").replace(/\r/g, "\n")
}

// Rewrites one server-sent event frame. A frame whose data isn't a single JSON
// payload, and the `[DONE]` sentinel, pass through unchanged.
export function rewriteFrame(frame) {
  const lines = normalizeFrame(frame).split("\n")
  const indexes = []
  for (let index = 0; index < lines.length; index += 1) {
    if (lines[index].startsWith("data:")) indexes.push(index)
  }
  if (!indexes.length) return frame
  // A frame can carry several data lines, which the specification joins with
  // a newline.
  const payload = indexes.map((index) => lines[index].slice(5).replace(/^ /, "")).join("\n")
  if (payload === "[DONE]") return frame
  let parsed
  try {
    parsed = JSON.parse(payload)
  } catch {
    return frame
  }
  const output = [...lines]
  output[indexes[0]] = `data: ${JSON.stringify(rewriteUsage(parsed))}`
  for (let index = indexes.length - 1; index > 0; index -= 1) output.splice(indexes[index], 1)
  return output.join("\n")
}

// Finds the end of the first complete frame in the buffer.
function findFrameEnd(buffer) {
  const match = FRAME_END.exec(buffer)
  if (!match) return null
  return { end: match.index, length: match[0].length }
}

// An error that carries the status the client should see.
class HttpError extends Error {
  constructor(status, message) {
    super(message)
    this.status = status
  }
}

// A failure that a later attempt can still get past.
export function isRetryableError(error) {
  if (error?.name === "AbortError") return true
  const code = error?.cause?.code ?? error?.code
  if (typeof code === "string" && RETRYABLE_CODES.has(code)) return true
  if (error instanceof TypeError) return true
  return /fetch failed|socket hang up|network|timed? ?out/i.test(error?.message ?? "")
}

// Sends the request upstream and retries the failures that a later attempt
// can get past. The retry stops as soon as the client goes away, because then
// there is nobody left to answer.
export async function fetchUpstream(fetchImpl, url, init, options = {}) {
  const {
    retries = RETRY_DELAYS_MS.length,
    retryDelaysMs = RETRY_DELAYS_MS,
    timeoutMs = UPSTREAM_TIMEOUT_MS,
    sleep: wait = sleep,
  } = options
  let lastError
  for (let attempt = 0; attempt <= retries; attempt += 1) {
    const controller = new AbortController()
    let timedOut = false
    const timer = timeoutMs > 0
      ? setTimeout(() => {
          timedOut = true
          controller.abort()
        }, timeoutMs)
      : undefined
    const signal = init.signal ? AbortSignal.any([init.signal, controller.signal]) : controller.signal
    try {
      const response = await fetchImpl(url, { ...init, signal })
      if (!RETRYABLE_STATUS.has(response.status) || attempt === retries) return response
      await response.body?.cancel().catch(() => {})
      lastError = new Error(`the upstream answered ${response.status}`)
    } catch (error) {
      // The client left, so there is nobody left to answer.
      if (init.signal?.aborted) throw error
      if (attempt === retries || !(timedOut || isRetryableError(error))) throw error
      lastError = error
    } finally {
      if (timer) clearTimeout(timer)
    }
    console.error(`opencode-go-cost-proxy: ${lastError?.message ?? "upstream failure"}, retrying`)
    await wait(retryDelaysMs[Math.min(attempt, retryDelaysMs.length - 1)])
  }
  throw lastError ?? new Error("the upstream request failed")
}

function readBody(req, limit) {
  return new Promise((resolve, reject) => {
    const chunks = []
    let size = 0
    let settled = false
    req.on("data", (chunk) => {
      if (settled) return
      size += chunk.length
      if (size > limit) {
        settled = true
        reject(new HttpError(413, "request body too large"))
        return
      }
      chunks.push(chunk)
    })
    req.on("end", () => {
      if (settled) return
      settled = true
      resolve(Buffer.concat(chunks))
    })
    req.on("error", (error) => {
      if (settled) return
      settled = true
      reject(error)
    })
  })
}

async function handle(req, res, options) {
  const { upstream, fetchImpl, maxBodyBytes, retry } = options
  const url = new URL(req.url ?? "/", "http://127.0.0.1")
  if (url.pathname === "/healthz") {
    res.writeHead(200, { "content-type": "application/json" })
    res.end(JSON.stringify({ status: "ok" }))
    return
  }

  // The upstream request follows the downstream one. A client that goes away
  // first cancels the upstream generation instead of leaving it running.
  const controller = new AbortController()
  let finished = false
  const cancelUpstream = () => {
    if (!finished) controller.abort()
  }
  res.on("close", cancelUpstream)
  req.on("error", cancelUpstream)

  let body
  try {
    body = await readBody(req, maxBodyBytes)
  } catch (error) {
    if (error instanceof HttpError) {
      res.writeHead(error.status, { "content-type": "application/json" })
      res.end(JSON.stringify({ error: error.message }), () => req.destroy())
      return
    }
    throw error
  }

  const headers = {}
  for (const [name, value] of Object.entries(req.headers)) {
    if (value === undefined) continue
    if (DROPPED_REQUEST_HEADERS.has(name)) continue
    headers[name] = value
  }
  // Identity keeps the body readable, so the proxy can rewrite it.
  headers["accept-encoding"] = "identity"

  const response = await fetchUpstream(fetchImpl, `${upstream}${url.pathname}${url.search}`, {
    method: req.method,
    headers,
    body: req.method === "GET" || req.method === "HEAD" ? undefined : body,
    signal: controller.signal,
  }, retry)

  const outHeaders = {}
  for (const [name, value] of response.headers) {
    if (value === undefined) continue
    if (DROPPED_RESPONSE_HEADERS.has(name)) continue
    outHeaders[name] = value
  }
  const contentType = response.headers.get("content-type") ?? ""

  if (contentType.includes("text/event-stream")) {
    res.writeHead(response.status, outHeaders)
    const decoder = new TextDecoder()
    let buffer = ""
    for await (const chunk of response.body) {
      buffer += decoder.decode(chunk, { stream: true })
      for (;;) {
        const frame = findFrameEnd(buffer)
        if (!frame) break
        const text = buffer.slice(0, frame.end)
        buffer = buffer.slice(frame.end + frame.length)
        res.write(rewriteFrame(text))
        res.write("\n\n")
      }
    }
    buffer += decoder.decode()
    if (buffer) res.write(buffer)
    finished = true
    res.end()
    return
  }

  if (contentType.includes("application/json")) {
    const text = await response.text()
    let payload
    try {
      payload = JSON.parse(text)
    } catch {
      payload = undefined
    }
    res.writeHead(response.status, outHeaders)
    finished = true
    res.end(payload === undefined ? text : JSON.stringify(rewriteUsage(payload)))
    return
  }

  // Anything else, including error payloads and non-JSON bodies, passes
  // through untouched.
  res.writeHead(response.status, outHeaders)
  if (response.body) {
    for await (const chunk of response.body) res.write(Buffer.from(chunk))
  }
  finished = true
  res.end()
}

export function createServer(options = {}) {
  const {
    upstream = UPSTREAM,
    fetchImpl = fetch,
    maxBodyBytes = MAX_BODY_BYTES,
    retries = RETRY_DELAYS_MS.length,
    retryDelaysMs = RETRY_DELAYS_MS,
    timeoutMs = UPSTREAM_TIMEOUT_MS,
    sleep: wait = sleep,
  } = options
  const server = http.createServer((req, res) => {
    handle(req, res, {
      upstream,
      fetchImpl,
      maxBodyBytes,
      retry: { retries, retryDelaysMs, timeoutMs, sleep: wait },
    }).catch((error) => {
      // The client is gone, so there is nobody to answer.
      if (res.writableEnded || res.destroyed) return
      if (error?.name === "AbortError") {
        res.destroy()
        return
      }
      console.error(`opencode-go-cost-proxy: ${error?.message ?? error}`)
      if (res.headersSent) {
        // The response already started. A truncated body would read as a
        // success, so the connection is dropped instead.
        res.destroy()
        return
      }
      res.writeHead(502, { "content-type": "application/json" })
      res.end(JSON.stringify({ error: "upstream request failed" }))
    })
  })
  // A busy port or a socket error must not take the proxy down, because
  // OpenCode has no other way to reach the provider.
  server.on("error", (error) => {
    console.error(`opencode-go-cost-proxy: ${error?.message ?? error}`)
  })
  return server
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const server = createServer()
  // One failed request must not end the process. launchd restarts it, but
  // every request in between fails.
  process.on("uncaughtException", (error) => {
    console.error(`opencode-go-cost-proxy: uncaught exception: ${error?.message ?? error}`)
  })
  process.on("unhandledRejection", (reason) => {
    console.error(`opencode-go-cost-proxy: unhandled rejection: ${reason?.message ?? reason}`)
  })
  // The port is busy while the previous process is still shutting down, which
  // happens on every restart.
  let attempts = 0
  server.on("error", (error) => {
    if (error?.code !== "EADDRINUSE") return
    attempts += 1
    if (attempts > 5) {
      console.error("opencode-go-cost-proxy: the port stays busy, giving up")
      process.exit(1)
    }
    console.error("opencode-go-cost-proxy: the port is busy, retrying")
    setTimeout(() => server.listen(PORT, HOST), 1000)
  })
  server.listen(PORT, HOST, () => {
    console.log(`opencode-go-cost-proxy listening on ${HOST}:${PORT} -> ${UPSTREAM}`)
  })
  for (const signal of ["SIGINT", "SIGTERM"]) {
    process.on(signal, () => {
      server.close(() => process.exit(0))
      // A client that keeps its socket open would hold the close open.
      setTimeout(() => process.exit(0), 2000).unref()
    })
  }
}
