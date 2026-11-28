import { expect, test } from "bun:test"
import { allowanceText, compactAllowanceText, fetchLimits, metersByUrgency, nearestCap, parseLimits, probeProxy, resetText, severity } from "./usage"

const meter = (percent: number, limited = false, resetsAt = 0) => ({ percent, limited, resetsAt })

const payload = {
  workspace: { id: "ws_1", name: "Pedro", usageURL: "https://opencode.ai/console/usage" },
  go: {
    rolling: meter(5, false, 1_800_000),
    weekly: meter(22, false, 604_800_000),
    monthly: meter(11, false, 2_592_000_000),
  },
}

test("the allowance parses with its workspace", () => {
  const limits = parseLimits(payload)!
  expect(limits.workspace.usageURL).toBe("https://opencode.ai/console/usage")
  expect(limits.go?.weekly.percent).toBe(22)
  expect(limits.go?.weekly.limited).toBe(false)
  expect(limits.go?.rolling.resetsAt).toBe(1_800_000)
})

test("a missing meter leaves the allowance out", () => {
  const limits = parseLimits({ workspace: { id: "ws_1", usageURL: "" }, go: { rolling: meter(5) } })!
  expect(limits.go).toBeUndefined()
  expect(limits.workspace.id).toBe("ws_1")
})

test("a payload without a workspace is rejected", () => {
  expect(parseLimits({ go: payload.go })).toBeUndefined()
  expect(parseLimits(undefined)).toBeUndefined()
  expect(parseLimits("nonsense")).toBeUndefined()
})

test("a meter at or above the warning threshold warns", () => {
  expect(severity(meter(0))).toBe("normal")
  expect(severity(meter(79.9))).toBe("normal")
  expect(severity(meter(80))).toBe("warn")
  expect(severity(meter(100))).toBe("warn")
})

test("the window nearest its cap comes first", () => {
  const allowance = { rolling: meter(12), weekly: meter(91), monthly: meter(30) }
  expect(metersByUrgency(allowance).map(([key]) => key)).toEqual(["weekly", "monthly", "rolling"])
})

test("a tie keeps the window order", () => {
  const allowance = { rolling: meter(50), weekly: meter(50), monthly: meter(50) }
  expect(metersByUrgency(allowance).map(([key]) => key)).toEqual(["rolling", "weekly", "monthly"])
})

test("a limited meter reports an error", () => {
  expect(severity(meter(10, true))).toBe("error")
})

test("the allowance reads as one compact line", () => {
  const limits = parseLimits(payload)!
  expect(allowanceText(limits.go!)).toBe("Go 5h 5% · wk 22% · mo 11%")
  expect(compactAllowanceText(limits.go!, 0)).toBe("Go 22% → 7.0d")
})

test("the compact line names the window nearest its cap", () => {
  const allowance = { rolling: meter(12, false, 3_960_000), weekly: meter(91, false, 604_800_000), monthly: meter(30, false, 2_592_000_000) }
  expect(compactAllowanceText(allowance, 0)).toBe("Go 91% → 7.0d")
  expect(nearestCap(allowance)[0]).toBe("weekly")
  expect(compactAllowanceText({ rolling: meter(88, false, 3_960_000), weekly: meter(20), monthly: meter(30) }, 0)).toBe("Go 88% → 1.1h")
  expect(compactAllowanceText({ rolling: meter(12), weekly: meter(20), monthly: meter(77, false, 2_592_000_000) }, 0)).toBe("Go 77% → 30.0d")
})

test("a reset time reads as a duration", () => {
  expect(resetText(meter(5, false, 0), 0)).toBe("reset time unknown")
  expect(resetText(meter(5, false, 1000), 0)).toBe("resets in 1s")
  expect(resetText(meter(5, false, 7_200_000), 0)).toBe("resets in 2.0h")
  expect(resetText(meter(5, false, 604_800_000), 0)).toBe("resets in 7.0d")
  expect(resetText(meter(5, false, 2_592_000_000), 0)).toBe("resets in 30.0d")
  expect(resetText(meter(5, false, 1000), 2000)).toBe("reset due")
})

test("the client operation supplies the limits", async () => {
  const calls: unknown[] = []
  const limits = await fetchLimits({
    experimental: { usage: { limits: async (input?: unknown) => { calls.push(input); return { data: payload } } } },
  }, "/tmp/project")
  expect(limits?.go?.monthly.percent).toBe(11)
  expect(calls).toEqual([{ location: { directory: "/tmp/project" } }])
})

test("a server without the operation reports nothing", async () => {
  expect(await fetchLimits({})).toBeUndefined()
})

test("the proxy probe follows the health endpoint", async () => {
  const original = globalThis.fetch
  try {
    globalThis.fetch = (async () => new Response("{}", { status: 200 })) as unknown as typeof fetch
    expect(await probeProxy()).toBe(true)
    globalThis.fetch = (async () => new Response("{}", { status: 500 })) as unknown as typeof fetch
    expect(await probeProxy()).toBe(false)
    globalThis.fetch = (async () => { throw new Error("refused") }) as unknown as typeof fetch
    expect(await probeProxy()).toBe(false)
  } finally {
    globalThis.fetch = original
  }
})

test("a hanging proxy ends the health probe", async () => {
  const original = globalThis.fetch
  try {
    globalThis.fetch = ((_url: string, init?: { signal?: AbortSignal }) => new Promise((_, reject) => {
      init?.signal?.addEventListener("abort", () => reject(new Error("aborted")))
    })) as unknown as typeof fetch
    expect(await probeProxy(undefined, 50)).toBe(false)
  } finally {
    globalThis.fetch = original
  }
})

test("a hanging server ends the allowance request", async () => {
  const hanging = {
    experimental: {
      usage: {
        limits: (_input?: unknown, options?: { signal?: AbortSignal }) => new Promise((_, reject) => {
          options?.signal?.addEventListener("abort", () => reject(new Error("aborted")))
        }),
      },
    },
  }
  await expect(fetchLimits(hanging, "/tmp/project", undefined, 50)).rejects.toThrow("aborted")
})
