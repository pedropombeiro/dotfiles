import { expect, test } from "bun:test"
import { acquireMonitor, createMonitor } from "./monitor"
import type { ProbeResult } from "./probe"
import { resolveOptions } from "../index"
import { describeStatus, indicatorLabel, indicatorState } from "./status"

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
