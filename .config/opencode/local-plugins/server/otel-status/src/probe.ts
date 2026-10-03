import { createConnection } from "node:net"

export const PROTOCOLS = ["http/protobuf", "http/json", "grpc"] as const
export type Protocol = (typeof PROTOCOLS)[number]

interface Address {
  host: string
  port: number
}

export type ProbeTarget =
  | ({ kind: "otlp-http"; url: string; contentType: string; body: string } & Address)
  | ({ kind: "tcp" } & Address)

export interface ProbeResult {
  ok: boolean
  latencyMs: number
  error?: string
}

export type Probe = (target: ProbeTarget, timeoutMs: number) => Promise<ProbeResult>

const DEFAULT_PORTS: Record<string, number> = { "http:": 80, "https:": 443 }
const GRPC_PORT = 4317

// An empty protobuf message encodes as zero bytes, and `{}` is its JSON form,
// so these are valid export requests that carry no telemetry.
const EMPTY_REQUEST: Record<Exclude<Protocol, "grpc">, { contentType: string; body: string }> = {
  "http/protobuf": { contentType: "application/x-protobuf", body: "" },
  "http/json": { contentType: "application/json", body: "{}" },
}

// Matches how the exporter builds signal URLs: `<endpoint path>/v1/<signal>`.
function signalUrl(url: URL, signal: string): string {
  const signalURL = new URL(url)
  signalURL.pathname = `${url.pathname.replace(/\/$/, "")}/v1/${signal}`
  return signalURL.toString()
}

export function resolveTarget(endpoint: string, protocol: Protocol): ProbeTarget | undefined {
  let url: URL
  try {
    url = new URL(endpoint)
  } catch {
    return undefined
  }
  if (!url.hostname) return undefined
  const address = {
    host: url.hostname.replace(/^\[|\]$/g, ""),
    port: url.port ? Number(url.port) : (DEFAULT_PORTS[url.protocol] ?? GRPC_PORT),
  }
  if (protocol === "grpc") return { kind: "tcp", ...address }
  if (url.protocol !== "http:" && url.protocol !== "https:") return undefined
  return { kind: "otlp-http", url: signalUrl(url, "metrics"), ...EMPTY_REQUEST[protocol], ...address }
}

export function tcpProbe(target: Address, timeoutMs: number): Promise<ProbeResult> {
  return new Promise((resolve) => {
    const start = performance.now()
    const elapsed = () => Math.round(performance.now() - start)
    let settled = false
    const socket = createConnection({ host: target.host, port: target.port })
    const finish = (result: ProbeResult) => {
      if (settled) return
      settled = true
      clearTimeout(timer)
      socket.destroy()
      resolve(result)
    }
    const timer = setTimeout(
      () => finish({ ok: false, latencyMs: elapsed(), error: `timed out after ${timeoutMs}ms` }),
      timeoutMs,
    )
    socket.once("connect", () => finish({ ok: true, latencyMs: elapsed() }))
    socket.once("error", (error) => finish({ ok: false, latencyMs: elapsed(), error: error.message || String(error) }))
  })
}

export interface OtlpProbeDeps {
  fetch: typeof fetch
  tcp: (target: Address, timeoutMs: number) => Promise<ProbeResult>
}

export async function otlpProbe(
  target: Extract<ProbeTarget, { kind: "otlp-http" }>,
  timeoutMs: number,
  deps: OtlpProbeDeps = { fetch, tcp: tcpProbe },
): Promise<ProbeResult> {
  const start = performance.now()
  const elapsed = () => Math.round(performance.now() - start)
  try {
    const response = await deps.fetch(target.url, {
      method: "POST",
      headers: { "Content-Type": target.contentType },
      body: target.body,
      redirect: "manual",
      signal: AbortSignal.timeout(timeoutMs),
    })
    await response.body?.cancel().catch(() => {})
    if (response.ok) return { ok: true, latencyMs: elapsed() }
    return { ok: false, latencyMs: elapsed(), error: `HTTP ${response.status} from ${new URL(target.url).pathname}` }
  } catch (error) {
    const latencyMs = elapsed()
    if (error instanceof Error && error.name === "TimeoutError") {
      return { ok: false, latencyMs, error: `timed out after ${timeoutMs}ms` }
    }
    // Bun's fetch reports DNS, refused, and unreachable failures alike, so a
    // plain connect finds the cause. If it connects, TLS or HTTP failed.
    const message = error instanceof Error ? error.message : String(error)
    const tcp = await deps.tcp(target, Math.max(1, timeoutMs - latencyMs))
    return { ok: false, latencyMs, error: tcp.ok ? `connected, but the request failed: ${message}` : tcp.error }
  }
}

export const probe: Probe = (target, timeoutMs) =>
  target.kind === "tcp" ? tcpProbe(target, timeoutMs) : otlpProbe(target, timeoutMs)
