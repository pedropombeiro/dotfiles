import { expect, test } from "bun:test"
import { acquireMonitor, createMonitor } from "./monitor"
import type { ProbeResult } from "./probe"
import { hostNameFrom, parseHeaders, resolveOptions } from "../index"
import {
  describeStatus,
  hostWarning,
  indicatorLabel,
  indicatorState,
  indicatorTone,
  MISSING_HOST_WARNING,
} from "./status"

function deferred() {
  let resolve!: (result: ProbeResult) => void
  const promise = new Promise<ProbeResult>((done) => (resolve = done))
  return { promise, resolve }
}

test("starts checking, then reports results and recovery", async () => {
  const results: ProbeResult[] = [
    { ok: false, latencyMs: 3, error: "connect EHOSTUNREACH" },
    { ok: true, latencyMs: 7 },
  ]
  const monitor = createMonitor({
    endpoint: "https://otel.example.com",
    intervalMs: 60_000,
    protocol: "http/protobuf",
    timeoutMs: 100,
    probe: async () => results.shift()!,
    now: () => 1000,
  })
  const seen: string[] = []
  monitor.subscribe((status) => seen.push(status.state))
  try {
    expect(monitor.snapshot().state).toBe("checking")
    await Bun.sleep(0)
    expect(monitor.snapshot()).toMatchObject({
      state: "unreachable",
      error: "connect EHOSTUNREACH",
      checkedAt: 1000,
    })
    const recovered = await monitor.check()
    expect(recovered).toMatchObject({ state: "reachable", latencyMs: 7 })
    expect(recovered.error).toBeUndefined()
    expect(seen).toEqual(["unreachable", "reachable"])
  } finally {
    monitor.dispose()
  }
})

test("does not overlap checks", async () => {
  const pending = deferred()
  let calls = 0
  const monitor = createMonitor({
    endpoint: "https://otel.example.com",
    intervalMs: 60_000,
    protocol: "http/protobuf",
    timeoutMs: 100,
    probe: () => {
      calls += 1
      return pending.promise
    },
  })
  try {
    const first = monitor.check()
    const second = monitor.check()
    expect(first).toBe(second)
    pending.resolve({ ok: true, latencyMs: 1 })
    await first
    expect(calls).toBe(1)
  } finally {
    monitor.dispose()
  }
})

test("reports disabled and invalid endpoints without probing", async () => {
  let calls = 0
  const probe = async () => {
    calls += 1
    return { ok: true, latencyMs: 0 }
  }
  const disabled = createMonitor({ protocol: "http/protobuf", intervalMs: 1000, timeoutMs: 100, probe })
  const invalid = createMonitor({
    endpoint: "nope",
    protocol: "http/protobuf",
    intervalMs: 1000,
    timeoutMs: 100,
    probe,
  })
  expect((await disabled.check()).state).toBe("disabled")
  expect(await invalid.check()).toMatchObject({
    state: "unreachable",
    error: "invalid endpoint URL for http/protobuf",
  })
  expect(calls).toBe(0)
  disabled.dispose()
  invalid.dispose()
})

test("ignores results that arrive after disposal", async () => {
  const pending = deferred()
  const monitor = createMonitor({
    endpoint: "https://otel.example.com",
    intervalMs: 60_000,
    protocol: "http/protobuf",
    timeoutMs: 100,
    probe: () => pending.promise,
  })
  const seen: string[] = []
  monitor.subscribe((status) => seen.push(status.state))
  monitor.dispose()
  pending.resolve({ ok: true, latencyMs: 1 })
  await Bun.sleep(0)
  expect(monitor.snapshot().state).toBe("checking")
  expect(seen).toEqual([])
})

test("shares one monitor across plugin instances until the last release", () => {
  const options = {
    endpoint: "https://shared.example.com",
    protocol: "http/protobuf" as const,
    intervalMs: 60_000,
    timeoutMs: 100,
  }
  const first = acquireMonitor({ ...options, probe: () => new Promise(() => {}) })
  const second = acquireMonitor(options)
  expect(second.monitor).toBe(first.monitor)
  first.release()
  first.release()
  const third = acquireMonitor(options)
  expect(third.monitor).toBe(first.monitor)
  second.release()
  third.release()
  const fourth = acquireMonitor({ ...options, probe: () => new Promise(() => {}) })
  expect(fourth.monitor).not.toBe(first.monitor)
  fourth.release()
})

test("resolves options from plugin options and the environment", () => {
  expect(resolveOptions({}, {})).toEqual({
    endpoint: undefined,
    protocol: "grpc",
    intervalMs: 60_000,
    timeoutMs: 5000,
  })
  expect(resolveOptions({}, { OPENCODE_OTLP_ENDPOINT: "http://env:4318" }).endpoint).toBe("http://env:4318")
  expect(resolveOptions({}, { OPENCODE_OTLP_PROTOCOL: "http/json" }).protocol).toBe("http/json")
  expect(resolveOptions({ protocol: "bogus" }, { OPENCODE_OTLP_PROTOCOL: "bogus" }).protocol).toBe("grpc")
  expect(
    resolveOptions(
      { endpoint: "https://otel.example.com", protocol: "http/protobuf", intervalSeconds: 2, timeoutSeconds: 10 },
      { OPENCODE_OTLP_ENDPOINT: "http://env:4318", OPENCODE_OTLP_PROTOCOL: "grpc" },
    ),
  ).toEqual({ endpoint: "https://otel.example.com", protocol: "http/protobuf", intervalMs: 2000, timeoutMs: 2000 })
  expect(resolveOptions({}, { OPENCODE_RESOURCE_ATTRIBUTES: "host.name=laptop" }).hostName).toBe("laptop")
})

test("parses OTLP headers like the exporter", () => {
  // Built at runtime so the test file holds no literal credential.
  const encoded = btoa("ab:c")
  expect(encoded.endsWith("==")).toBe(true)
  expect(parseHeaders(`Authorization=Basic ${encoded}`)).toEqual({ Authorization: `Basic ${encoded}` })
  expect(parseHeaders(` a = 1 ,b=x=y,=skipped,novalue,c=`)).toEqual({ a: "1", b: "x=y", c: "" })
  expect(parseHeaders("")).toEqual({})
  expect(parseHeaders(undefined)).toEqual({})
})

test("reads headers from OPENCODE_OTLP_HEADERS only when set", () => {
  const authorization = ["Basic", btoa("ab:c")].join(" ")
  expect(resolveOptions({}, { OPENCODE_OTLP_HEADERS: `Authorization=${authorization}` }).headers).toEqual({
    Authorization: authorization,
  })
  expect("headers" in resolveOptions({}, { OPENCODE_OTLP_HEADERS: "" })).toBe(false)
  expect("headers" in resolveOptions({}, {})).toBe(false)
})

test("passes headers to the probe, keeps them out of statuses, and separates monitors by credential", async () => {
  const encoded = btoa("ab:c")
  const options = { endpoint: "https://otel.example.com", protocol: "http/protobuf" as const, intervalMs: 60_000 }
  const seen: Array<Record<string, string>> = []
  const monitor = createMonitor({
    ...options,
    timeoutMs: 100,
    headers: { Authorization: `Basic ${encoded}` },
    probe: async (target) => {
      if (target.kind === "otlp-http") seen.push(target.headers)
      return { ok: true, latencyMs: 1 }
    },
  })
  const status = await monitor.check()
  monitor.dispose()
  expect(seen.at(-1)).toEqual({ Authorization: `Basic ${encoded}` })
  expect(JSON.stringify(status)).not.toContain(encoded)

  const never = () => new Promise<ProbeResult>(() => {})
  const first = acquireMonitor({ ...options, timeoutMs: 100, headers: { Authorization: "a" }, probe: never })
  const same = acquireMonitor({ ...options, timeoutMs: 100, headers: { Authorization: "a" } })
  const other = acquireMonitor({ ...options, timeoutMs: 100, headers: { Authorization: "b" }, probe: never })
  const none = acquireMonitor({ ...options, timeoutMs: 100, probe: never })
  expect(same.monitor).toBe(first.monitor)
  expect(other.monitor).not.toBe(first.monitor)
  expect(none.monitor).not.toBe(first.monitor)
  for (const lease of [first, same, other, none]) lease.release()
})

test("parses host.name from resource attributes", () => {
  expect(hostNameFrom("host.name=laptop")).toBe("laptop")
  expect(hostNameFrom("team=x, host.name = my%20box ,env=prod")).toBe("my box")
  expect(hostNameFrom("host.name=bad%zz")).toBe("bad%zz")
  expect(hostNameFrom("host.name=")).toBeUndefined()
  expect(hostNameFrom("host.namespace=x,service.name=y")).toBeUndefined()
  expect(hostNameFrom("")).toBeUndefined()
  expect(hostNameFrom(undefined)).toBeUndefined()
})

test("carries the host name into every status and keeps separate monitors per host", async () => {
  const options = { endpoint: "https://otel.example.com", protocol: "http/protobuf" as const, intervalMs: 60_000 }
  const monitor = createMonitor({
    ...options,
    timeoutMs: 100,
    hostName: "laptop",
    probe: async () => ({ ok: true, latencyMs: 1 }),
  })
  expect(monitor.snapshot().hostName).toBe("laptop")
  expect((await monitor.check()).hostName).toBe("laptop")
  monitor.dispose()

  const withHost = acquireMonitor({ ...options, timeoutMs: 100, hostName: "a", probe: () => new Promise(() => {}) })
  const withoutHost = acquireMonitor({ ...options, timeoutMs: 100, probe: () => new Promise(() => {}) })
  expect(withoutHost.monitor).not.toBe(withHost.monitor)
  withHost.release()
  withoutHost.release()
})

test("warns when the service has no host name", () => {
  const reachable = {
    state: "reachable" as const,
    intervalMs: 60_000,
    protocol: "http/protobuf",
    endpoint: "https://otel.example.com",
    checkedAt: 0,
    latencyMs: 4,
  }
  const named = { ...reachable, hostName: "laptop" }
  expect(hostWarning(named)).toBeUndefined()
  expect(hostWarning(reachable)).toBe(MISSING_HOST_WARNING)
  expect(hostWarning({ state: "disabled", intervalMs: 60_000, protocol: "grpc" })).toBeUndefined()
  expect(hostWarning(undefined)).toBeUndefined()

  expect(indicatorTone(named, 1000)).toBe("success")
  expect(indicatorTone(reachable, 1000)).toBe("warning")
  expect(indicatorTone({ ...reachable, state: "unreachable" }, 1000)).toBe("error")
  expect(indicatorTone(reachable, 10_000_000)).toBe("muted")
  expect(indicatorTone(undefined, 0)).toBe("muted")

  expect(describeStatus(named, 1000)).toContain("Host: laptop")
  expect(describeStatus(reachable, 1000)).toContain(`Warning: ${MISSING_HOST_WARNING}`)
})

test("marks stale results as unknown and formats details", () => {
  const status = {
    state: "unreachable" as const,
    intervalMs: 30_000,
    protocol: "http/protobuf",
    endpoint: "https://otel.example.com",
    checkedAt: 0,
    latencyMs: 4,
    error: "connect EHOSTUNREACH",
  }
  expect(indicatorState(status, 30_000)).toBe("unreachable")
  expect(indicatorState(status, 90_001)).toBe("unknown")
  expect(indicatorState(undefined, 0)).toBe("unknown")
  expect(indicatorLabel("reachable")).toBe("● 🔭")
  expect(indicatorLabel("unknown")).toBe("○ 🔭")
  expect(indicatorLabel("disabled")).toBe("")
  expect(describeStatus(status, 12_000)).toContain("Error: connect EHOSTUNREACH")
  expect(describeStatus(status, 12_000)).toContain("Last check: 12s ago")
  expect(describeStatus(status, 12_000)).toContain("Endpoint: https://otel.example.com (http/protobuf)")
  expect(describeStatus(status, 12_000)).toContain("Sends an empty OTLP metrics request")

  const reachable = { ...status, state: "reachable" as const }
  expect(describeStatus(reachable, 12_000)).toContain("Response time: 4ms")
  expect(describeStatus({ ...reachable, protocol: "grpc" }, 12_000)).toContain("Connect time: 4ms")
  expect(describeStatus({ ...reachable, protocol: "grpc" }, 12_000)).toContain("Checks TCP reachability only")
})
