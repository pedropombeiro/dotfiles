import { afterEach, expect, test } from "bun:test"
import { createServer, type Server } from "node:net"
import { otlpProbe, resolveTarget, tcpProbe, type ProbeTarget } from "./probe"

type HttpTarget = Extract<ProbeTarget, { kind: "otlp-http" }>

const cleanups: Array<() => unknown> = []

afterEach(async () => {
  await Promise.all(cleanups.splice(0).map((cleanup) => cleanup()))
})

interface Received {
  method: string
  path: string
  contentType: string | null
  authorization: string | null
  body: string
}

function serve(respond: (request: Received) => Response | Promise<Response>) {
  const received: Received[] = []
  const server = Bun.serve({
    port: 0,
    hostname: "127.0.0.1",
    async fetch(request) {
      const entry = {
        method: request.method,
        path: new URL(request.url).pathname,
        contentType: request.headers.get("content-type"),
        authorization: request.headers.get("authorization"),
        body: await request.text(),
      }
      received.push(entry)
      return respond(entry)
    },
  })
  cleanups.push(() => server.stop(true))
  return { endpoint: `http://127.0.0.1:${server.port}`, received }
}

function target(
  endpoint: string,
  protocol: "http/protobuf" | "http/json" = "http/protobuf",
  headers: Record<string, string> = {},
): HttpTarget {
  const resolved = resolveTarget(endpoint, protocol, headers)
  if (resolved?.kind !== "otlp-http") throw new Error(`unexpected target for ${endpoint}`)
  return resolved
}

function closedPort(): Promise<number> {
  const server: Server = createServer()
  return new Promise((resolve) =>
    server.listen(0, "127.0.0.1", () => {
      const address = server.address()
      server.close(() => resolve(typeof address === "object" && address ? address.port : 0))
    }),
  )
}

test("resolves HTTP targets to the metrics signal URL and gRPC to a TCP address", () => {
  expect(resolveTarget("https://otel.example.com", "http/protobuf")).toEqual({
    kind: "otlp-http",
    url: "https://otel.example.com/v1/metrics",
    contentType: "application/x-protobuf",
    body: "",
    headers: {},
    host: "otel.example.com",
    port: 443,
  })
  expect(resolveTarget("http://collector:4318/otlp/", "http/json")).toMatchObject({
    url: "http://collector:4318/otlp/v1/metrics",
    contentType: "application/json",
    body: "{}",
    port: 4318,
  })
  expect(resolveTarget("http://collector", "grpc")).toEqual({ kind: "tcp", host: "collector", port: 80 })
  expect(resolveTarget("grpc://collector", "grpc")).toEqual({ kind: "tcp", host: "collector", port: 4317 })
  expect(resolveTarget("http://[::1]:4318", "grpc")).toEqual({ kind: "tcp", host: "::1", port: 4318 })
  expect(resolveTarget("grpc://collector", "http/protobuf")).toBeUndefined()
  expect(resolveTarget("not a url", "http/protobuf")).toBeUndefined()
})

test("sends an empty protobuf export request and accepts a 2xx response", async () => {
  const collector = serve(() => new Response(new Uint8Array([0x0a, 0x00]), { status: 200 }))
  const result = await otlpProbe(target(collector.endpoint), 1000)
  expect(result.ok).toBe(true)
  expect(result.error).toBeUndefined()
  expect(collector.received).toEqual([
    { method: "POST", path: "/v1/metrics", contentType: "application/x-protobuf", authorization: null, body: "" },
  ])
})

test("sends configured headers without letting them override the content type", async () => {
  // Built at runtime so the test file holds no literal credential.
  const authorization = ["Basic", btoa("ab:c")].join(" ")
  const collector = serve(() => new Response(null, { status: 200 }))
  const result = await otlpProbe(
    target(collector.endpoint, "http/protobuf", { Authorization: authorization, "content-type": "text/plain" }),
    1000,
  )
  expect(result.ok).toBe(true)
  expect(collector.received[0]).toMatchObject({ authorization, contentType: "application/x-protobuf" })
})

test("does not include headers in error messages", async () => {
  const authorization = ["Basic", btoa("ab:c")].join(" ")
  const collector = serve(() => new Response("no", { status: 401 }))
  const result = await otlpProbe(target(collector.endpoint, "http/protobuf", { Authorization: authorization }), 1000)
  expect(result).toMatchObject({ ok: false, error: "HTTP 401 from /v1/metrics" })
  expect(JSON.stringify(result)).not.toContain(btoa("ab:c"))
})

test("sends an empty JSON export request for http/json", async () => {
  const collector = serve(() => Response.json({}))
  const result = await otlpProbe(target(collector.endpoint, "http/json"), 1000)
  expect(result.ok).toBe(true)
  expect(collector.received[0]).toMatchObject({ contentType: "application/json", body: "{}" })
})

test("reports non-2xx responses with their status and path", async () => {
  for (const status of [404, 415, 503]) {
    const collector = serve(() => new Response("no", { status }))
    const result = await otlpProbe(target(collector.endpoint), 1000)
    expect(result).toMatchObject({ ok: false, error: `HTTP ${status} from /v1/metrics` })
  }
})

test("does not follow redirects", async () => {
  const collector = serve(() => new Response(null, { status: 302, headers: { location: "/elsewhere" } }))
  const result = await otlpProbe(target(collector.endpoint), 1000)
  expect(result).toMatchObject({ ok: false, error: "HTTP 302 from /v1/metrics" })
  expect(collector.received).toHaveLength(1)
})

test("times out when the collector does not answer", async () => {
  const collector = serve(() => Bun.sleep(300).then(() => new Response()))
  const result = await otlpProbe(target(collector.endpoint), 50)
  expect(result).toMatchObject({ ok: false, error: "timed out after 50ms" })
})

test("uses a TCP connect to explain network failures", async () => {
  const port = await closedPort()
  const result = await otlpProbe(target(`http://127.0.0.1:${port}`), 1000)
  expect(result.ok).toBe(false)
  expect(result.error).toContain("ECONNREFUSED")
})

test("reports a request failure after a successful connect", async () => {
  const result = await otlpProbe(target("https://otel.example.com"), 1000, {
    fetch: (async () => {
      throw new Error("certificate has expired")
    }) as unknown as typeof fetch,
    tcp: async () => ({ ok: true, latencyMs: 1 }),
  })
  expect(result).toMatchObject({ ok: false, error: "connected, but the request failed: certificate has expired" })
})

test("TCP probe reports open, refused, unresolvable, and silent hosts", async () => {
  const open = createServer((socket) => socket.destroy())
  await new Promise<void>((resolve) => open.listen(0, "127.0.0.1", resolve))
  cleanups.push(() => new Promise((resolve) => open.close(resolve)))
  const address = open.address()
  const port = typeof address === "object" && address ? address.port : 0

  expect((await tcpProbe({ host: "127.0.0.1", port }, 1000)).ok).toBe(true)
  expect(await tcpProbe({ host: "127.0.0.1", port: await closedPort() }, 1000)).toMatchObject({ ok: false })
  expect(await tcpProbe({ host: "otel-status.invalid", port: 443 }, 2000)).toMatchObject({ ok: false })
  const silent = await tcpProbe({ host: "10.255.255.1", port: 443 }, 50)
  expect(silent.ok).toBe(false)
  expect(silent.error).toMatch(/timed out after 50ms|EHOSTUNREACH|ENETUNREACH/)
})
