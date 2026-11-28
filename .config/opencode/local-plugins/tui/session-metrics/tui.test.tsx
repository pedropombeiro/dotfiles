/** @jsxImportSource @opentui/solid */
import { expect, test } from "bun:test"
import { RGBA } from "@opentui/core"
import { testRender } from "@opentui/solid"
import { createSignal, Show } from "solid-js"
import type { Context, SlotClaim } from "@opencode/plugin/tui/context"
import plugin from "./tui"

test("sidebar lifecycle controls fallback and preserves native footer space", async () => {
  const claims: SlotClaim[] = []
  const session = { id: "ses_one", time: { created: 0 }, model: { id: "model", providerID: "provider" } }
  const records = [
    { id: "msg_compact", type: "compaction", status: "completed", reason: "auto", summary: "A summary", time: { created: 0 } },
    { id: "msg_assistant", type: "assistant", time: { created: 100, streamed: 1100, completed: 1100 }, model: session.model, content: [], tokens: { input: 100, cache: { read: 900, write: 0 } } },
  ]
  const color = RGBA.fromInts(200, 200, 200)
  const context = {
    options: {}, theme: { text: { base: color, muted: color, feedback: { warning: { base: color }, error: { base: color } } } },
    client: {
      session: { get: async () => session, list: async () => ({ data: [], cursor: {} }) },
      message: { list: async () => ({ data: records, cursor: {} }) },
    },
    data: { listen: () => () => {}, session: { list: () => [session], get: () => session, status: () => "idle", message: { list: () => records } } },
    keymap: { layer: () => {} },
    ui: { slot: (claim: SlotClaim) => { claims.push(claim); return () => {} }, panel: { open: () => true } },
  } as unknown as Context
  const cleanup = plugin.setup(context) as () => void
  const side = claims.find((claim) => claim.append === "sidebar.content")!
  const footer = claims.find((claim) => claim.append === "prompt.footer.status")!
  const [shown, show] = createSignal(false)
  const [width, resize] = createSignal(70)
  const app = await testRender(() => <box>
    <Show when={shown()}>{side.render({ sessionID: "ses_one" } as never)}</Show>
    <box flexDirection="row" height={1} width={width()}>
      <text flexShrink={0}>64K (6%) · $0.93</text>
      {footer.render({ sessionID: "ses_one", mode: "normal", showDetails: true } as never)}
    </box>
  </box>, { width: 70, height: 15 })
  try {
    await app.renderOnce()
    await Bun.sleep(20)
    await app.renderOnce()
    expect(app.captureCharFrame()).toContain("active 1s")
    expect(app.captureCharFrame()).not.toContain("compact")
    expect(app.captureCharFrame()).not.toContain("cache")
    show(true)
    await app.renderOnce()
    await app.renderOnce()
    expect(app.captureCharFrame()).toContain("Session metrics")
    expect(app.captureCharFrame()).toContain("Compactions 1")
    expect(app.captureCharFrame()).toContain("Cache 90% · last request")
    expect(app.captureCharFrame()).not.toContain("active 1s")
    show(false)
    await app.renderOnce()
    await app.renderOnce()
    expect(app.captureCharFrame()).toContain("active 1s")
    expect(app.captureCharFrame()).toContain("64K (6%) · $0.93")
    resize(16)
    await app.renderOnce()
    await app.renderOnce()
    expect(app.captureCharFrame()).toContain("64K (6%) · $0.93")
    expect(app.captureCharFrame()).not.toContain("active 1s")
  } finally {
    cleanup()
    app.renderer.destroy()
  }
})

test("clicking an indicator opens its detail dialog", async () => {
  const claims: SlotClaim[] = []
  const session = { id: "ses_one", time: { created: 0 }, model: { id: "model", providerID: "provider" } }
  const records = [
    { id: "msg_compact", type: "compaction", status: "completed", reason: "auto", summary: "A summary", time: { created: 0 } },
    { id: "msg_assistant", type: "assistant", time: { created: 100, streamed: 2100, completed: 2100 }, model: session.model, content: [], tokens: { input: 100, cache: { read: 900, write: 0 } } },
  ]
  const color = RGBA.fromInts(200, 200, 200)
  const selects: { title: string }[] = []
  const dialogs: (() => unknown)[] = []
  const toasts: string[] = []
  let cleared = 0
  const context = {
    options: {}, theme: { text: { base: color, muted: color, feedback: { warning: { base: color }, error: { base: color } }, action: { primary: { focused: color } } }, background: { action: { primary: { focused: color } } } }, renderer: { height: 30 },
    client: {
      session: { get: async () => session, list: async () => ({ data: [], cursor: {} }) },
      message: { list: async () => ({ data: records, cursor: {} }) },
    },
    data: { listen: () => () => {}, session: { list: () => [session], get: () => session, status: () => "idle", message: { list: () => records } } },
    keymap: { layer: () => {} },
    ui: {
      slot: (claim: SlotClaim) => { claims.push(claim); return () => {} }, panel: { open: () => true },
      toast: { show: (input: { message: string }) => toasts.push(input.message) },
      dialog: {
        set: () => {}, show: (render: () => unknown) => dialogs.push(render),
        select: async (input: { title: string }) => { selects.push(input); return undefined },
        clear: () => { cleared += 1 },
      },
    },
  } as unknown as Context
  const cleanup = plugin.setup(context) as () => void
  const footer = claims.find((claim) => claim.append === "prompt.footer.status")!
  const side = claims.find((claim) => claim.append === "sidebar.content")!
  const [shown, show] = createSignal(false)
  const app = await testRender(() => <box>
    <Show when={shown()}>{side.render({ sessionID: "ses_one" } as never)}</Show>
    <box flexDirection="row" height={1} width={70}>
      {footer.render({ sessionID: "ses_one", mode: "normal", showDetails: true } as never)}
    </box>
  </box>, { width: 70, height: 15 })
  const find = (text: string) => {
    const lines = app.captureCharFrame().split("\n")
    const y = lines.findIndex((line) => line.includes(text))
    return { x: lines[y]?.indexOf(text) ?? -1, y }
  }
  const click = async (text: string) => {
    const at = find(text)
    expect(at.x).toBeGreaterThanOrEqual(0)
    await app.mockMouse.click(at.x + 1, at.y)
    await Bun.sleep(10)
  }
  try {
    await app.renderOnce()
    await Bun.sleep(20)
    await app.renderOnce()

    await click("active 2s")
    expect(dialogs).toHaveLength(1)

    show(true)
    await app.renderOnce()
    await app.renderOnce()
    await click("Compactions 1")
    expect(selects.map((input) => input.title)).toEqual(["Compaction history"])
    expect((selects[0] as { actions?: { title: string }[] }).actions?.map((action) => action.title)).toEqual(["Close"])
    expect(dialogs).toHaveLength(1)
    await click("Cache 90% · last request")
    expect(dialogs).toHaveLength(2)
    await click("Active 2s")
    expect(dialogs).toHaveLength(3)
    expect(toasts).toEqual([])

    // Each indicator opens only its own detail.
    const frames: string[] = []
    for (const render of dialogs.slice(0, 2)) {
      const detail = await testRender(render as never, { width: 80, height: 40 })
      await detail.renderOnce()
      const frame = detail.captureCharFrame()
      frames.push(frame)
      const lines = frame.split("\n")
      const y = lines.findIndex((line) => line.includes("Close"))
      const before = cleared
      await detail.mockMouse.click(lines[y]!.indexOf("Close") + 1, y)
      await Bun.sleep(10)
      expect(cleared).toBe(before + 1)
      detail.renderer.destroy()
    }
    expect(frames[0]).toContain("Active wall time 2s")
    expect(frames[0]).not.toContain("Reported cache reuse")
    expect(frames[1]).toContain("Reported cache reuse 90%")
    expect(frames[1]).not.toContain("Active wall time")
    expect(frames[0]).toContain("Close")
    expect(frames[1]).toContain("Close")
  } finally {
    cleanup()
    app.renderer.destroy()
  }
})

// Builds a context for a session that runs on the Go subscription, with a
// stubbed allowance response and a stubbed proxy probe.
function goContext(providerID: string, probe: () => Promise<Response>, meters = { rolling: 5, weekly: 22, monthly: 11 }, options: { location?: string; fail?: boolean } = {}) {
  const claims: SlotClaim[] = []
  const dialogs: (() => unknown)[] = []
  const calls: unknown[] = []
  const session = { id: "ses_go", time: { created: 0 }, model: { id: "minimax-m3.1-flash", providerID } }
  const records = [
    { id: "msg_assistant", type: "assistant", time: { created: 100, streamed: 1100, completed: 1100 }, model: session.model, content: [], tokens: { input: 100, cache: { read: 900, write: 0 } } },
  ]
  const color = RGBA.fromInts(200, 200, 200)
  const context = {
    options: {}, location: options.location ? { directory: options.location } : undefined,
    theme: { text: { base: color, muted: color, feedback: { warning: { base: color }, error: { base: color } }, action: { primary: { focused: color } } }, background: { action: { primary: { focused: color } } } },
    client: {
      session: { get: async () => session, list: async () => ({ data: [], cursor: {} }) },
      message: { list: async () => ({ data: records, cursor: {} }) },
      experimental: {
        usage: {
          limits: async (input?: unknown) => {
            calls.push(input)
            if (options.fail) throw new Error("the server is unreachable")
            return {
              data: {
                workspace: { id: "ws_1", usageURL: "https://opencode.ai/console/usage" },
                go: {
                  rolling: { percent: meters.rolling, limited: false, resetsAt: Date.now() + 1_800_000 },
                  weekly: { percent: meters.weekly, limited: false, resetsAt: Date.now() + 604_800_000 },
                  monthly: { percent: meters.monthly, limited: false, resetsAt: Date.now() + 2_592_000_000 },
                },
              },
            }
          },
        },
      },
    },
    data: {
      listen: () => () => {},
      session: { list: () => [session], get: () => session, status: () => "idle", message: { list: () => records }, cost: () => 0.25 },
      location: { default: () => ({ directory: "/tmp/project" }) },
    },
    keymap: { layer: () => {} },
    ui: {
      slot: (claim: SlotClaim) => { claims.push(claim); return () => {} },
      panel: { open: () => true },
      dialog: { set: () => {}, show: (render: () => unknown) => { dialogs.push(render) } },
    },
    renderer: { height: 30 },
  } as unknown as Context
  const original = globalThis.fetch
  globalThis.fetch = probe as unknown as typeof fetch
  return { claims, context, session, original, dialogs, calls }
}

test("the Go allowance leads the sidebar and the footer for Go sessions", async () => {
  const { claims, context, original } = goContext("opencode-go", async () => new Response("{}", { status: 200 }))
  const cleanup = plugin.setup(context) as () => void
  const go = claims.find((claim) => claim.prepend === "sidebar.content")!
  const footer = claims.find((claim) => claim.append === "prompt.footer.status")!
  const app = await testRender(() => <box>
    {go.render({ sessionID: "ses_go" } as never)}
    <box flexDirection="row" height={1} width={70}>
      {footer.render({ sessionID: "ses_go", mode: "normal", showDetails: true } as never)}
    </box>
  </box>, { width: 70, height: 15 })
  try {
    await app.renderOnce()
    await Bun.sleep(50)
    await app.renderOnce()
    await app.renderOnce()
    const frame = app.captureCharFrame()
    expect(frame).toContain("Go 5h 5% · wk 22% · mo 11%")
    expect(frame).toContain("Go 22% →")
    expect(frame).not.toContain("Go proxy down")
  } finally {
    cleanup()
    app.renderer.destroy()
    globalThis.fetch = original
  }
})

test("the footer names the window nearest its cap", async () => {
  const { claims, context, original } = goContext("opencode-go", async () => new Response("{}", { status: 200 }), { rolling: 88, weekly: 20, monthly: 30 })
  const cleanup = plugin.setup(context) as () => void
  const footer = claims.find((claim) => claim.append === "prompt.footer.status")!
  const app = await testRender(() => <box>
    <box flexDirection="row" height={1} width={70}>
      {footer.render({ sessionID: "ses_go", mode: "normal", showDetails: true } as never)}
    </box>
  </box>, { width: 70, height: 15 })
  try {
    await app.renderOnce()
    await Bun.sleep(50)
    await app.renderOnce()
    await app.renderOnce()
    const frame = app.captureCharFrame()
    expect(frame).toContain("Go 88% →")
    expect(frame).not.toContain("Go 20% →")
    expect(frame).not.toContain("Go 30% →")
  } finally {
    cleanup()
    app.renderer.destroy()
    globalThis.fetch = original
  }
})

test("a stopped proxy warns in the sidebar", async () => {
  const { claims, context, original } = goContext("opencode-go", async () => { throw new Error("refused") })
  const cleanup = plugin.setup(context) as () => void
  const go = claims.find((claim) => claim.prepend === "sidebar.content")!
  const app = await testRender(() => <box>
    {go.render({ sessionID: "ses_go" } as never)}
  </box>, { width: 70, height: 15 })
  try {
    await app.renderOnce()
    await Bun.sleep(50)
    await app.renderOnce()
    await app.renderOnce()
    const frame = app.captureCharFrame()
    expect(frame).toContain("Go proxy down")
    expect(frame).toContain("Go 5h 5% · wk 22% · mo 11%")
  } finally {
    cleanup()
    app.renderer.destroy()
    globalThis.fetch = original
  }
})

test("the allowance panel leads with the window nearest its cap", async () => {
  const { claims, context, original, dialogs } = goContext("opencode-go", async () => new Response("{}", { status: 200 }), { rolling: 12, weekly: 91, monthly: 30 })
  const cleanup = plugin.setup(context) as () => void
  const go = claims.find((claim) => claim.prepend === "sidebar.content")!
  const app = await testRender(() => <box>
    {go.render({ sessionID: "ses_go" } as never)}
  </box>, { width: 70, height: 15 })
  try {
    await app.renderOnce()
    await Bun.sleep(50)
    await app.renderOnce()
    await app.renderOnce()
    const lines = app.captureCharFrame().split("\n")
    const y = lines.findIndex((line) => line.includes("Go 5h"))
    expect(y).toBeGreaterThanOrEqual(0)
    await app.mockMouse.click(lines[y]!.indexOf("Go 5h") + 1, y)
    await Bun.sleep(10)
    expect(dialogs).toHaveLength(1)
    const detail = await testRender(dialogs[0] as never, { width: 80, height: 40 })
    await detail.renderOnce()
    const frame = detail.captureCharFrame()
    expect(frame).toContain("Weekly 91%")
    expect(frame.indexOf("Weekly 91%")).toBeLessThan(frame.indexOf("Monthly 30%"))
    expect(frame.indexOf("Monthly 30%")).toBeLessThan(frame.indexOf("Rolling 5 hours 12%"))
    expect(frame).toContain("7.0d")
    detail.renderer.destroy()
  } finally {
    cleanup()
    app.renderer.destroy()
    globalThis.fetch = original
  }
})

test("a session outside Go keeps the allowance out", async () => {
  const { claims, context, original, calls } = goContext("gitlab", async () => new Response("{}", { status: 200 }))
  const cleanup = plugin.setup(context) as () => void
  const go = claims.find((claim) => claim.prepend === "sidebar.content")!
  const footer = claims.find((claim) => claim.append === "prompt.footer.status")!
  const app = await testRender(() => <box>
    {go.render({ sessionID: "ses_go" } as never)}
    <box flexDirection="row" height={1} width={70}>
      {footer.render({ sessionID: "ses_go", mode: "normal", showDetails: true } as never)}
    </box>
  </box>, { width: 70, height: 15 })
  try {
    await app.renderOnce()
    await Bun.sleep(50)
    await app.renderOnce()
    await app.renderOnce()
    const frame = app.captureCharFrame()
    expect(frame).not.toContain("Go 5h")
    expect(frame).not.toContain("Go proxy down")
    expect(frame).not.toContain("Go 22% →")
    expect(calls).toHaveLength(0)
  } finally {
    cleanup()
    app.renderer.destroy()
    globalThis.fetch = original
  }
})

test("the allowance is read for the current location", async () => {
  const { claims, context, original, calls } = goContext("opencode-go", async () => new Response("{}", { status: 200 }), undefined, { location: "/tmp/current" })
  const cleanup = plugin.setup(context) as () => void
  const go = claims.find((claim) => claim.prepend === "sidebar.content")!
  const app = await testRender(() => <box>
    {go.render({ sessionID: "ses_go" } as never)}
  </box>, { width: 70, height: 15 })
  try {
    await app.renderOnce()
    await Bun.sleep(50)
    await app.renderOnce()
    expect(calls[0]).toEqual({ location: { directory: "/tmp/current" } })
  } finally {
    cleanup()
    app.renderer.destroy()
    globalThis.fetch = original
  }
})

test("a failed allowance fetch reports the failure instead of a pending load", async () => {
  const { claims, context, original, dialogs } = goContext("opencode-go", async () => new Response("{}", { status: 200 }), undefined, { fail: true })
  const cleanup = plugin.setup(context) as () => void
  const go = claims.find((claim) => claim.prepend === "sidebar.content")!
  const app = await testRender(() => <box>
    {go.render({ sessionID: "ses_go" } as never)}
  </box>, { width: 70, height: 15 })
  try {
    await app.renderOnce()
    await Bun.sleep(50)
    await app.renderOnce()
    await app.renderOnce()
    const lines = app.captureCharFrame().split("\n")
    const y = lines.findIndex((line) => line.includes("Go allowance"))
    expect(y).toBeGreaterThanOrEqual(0)
    await app.mockMouse.click(lines[y]!.indexOf("Go allowance") + 1, y)
    await Bun.sleep(10)
    expect(dialogs).toHaveLength(1)
    const detail = await testRender(dialogs[0] as never, { width: 80, height: 40 })
    await detail.renderOnce()
    const frame = detail.captureCharFrame()
    expect(frame).toContain("Allowance unavailable")
    expect(frame).not.toContain("Loading")
    detail.renderer.destroy()
  } finally {
    cleanup()
    app.renderer.destroy()
    globalThis.fetch = original
  }
})
