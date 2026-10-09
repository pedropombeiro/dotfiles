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
    options: {}, theme: { text: { base: color, muted: color } },
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
    expect(app.captureCharFrame()).toContain("compact 1")
    expect(app.captureCharFrame()).toContain("cache 90%")
    show(true)
    await app.renderOnce()
    await app.renderOnce()
    expect(app.captureCharFrame()).toContain("Session metrics")
    expect(app.captureCharFrame()).not.toContain("compact 1")
    show(false)
    await app.renderOnce()
    await app.renderOnce()
    expect(app.captureCharFrame()).toContain("compact 1")
    expect(app.captureCharFrame()).toContain("64K (6%) · $0.93")
    resize(16)
    await app.renderOnce()
    await app.renderOnce()
    expect(app.captureCharFrame()).toContain("64K (6%) · $0.93")
    expect(app.captureCharFrame()).not.toContain("compact 1")
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
    options: {}, theme: { text: { base: color, muted: color, action: { primary: { focused: color } } }, background: { action: { primary: { focused: color } } } }, renderer: { height: 30 },
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

    await click("compact 1")
    expect(selects.map((input) => input.title)).toEqual(["Compaction history"])
    expect((selects[0] as { actions?: { title: string }[] }).actions?.map((action) => action.title)).toEqual(["Close"])
    expect(dialogs).toHaveLength(0)

    await click("cache 90%")
    expect(dialogs).toHaveLength(1)
    await click("active 2s")
    expect(dialogs).toHaveLength(2)

    show(true)
    await app.renderOnce()
    await app.renderOnce()
    await click("Compactions 1")
    expect(selects).toHaveLength(2)
    await click("Cache 90% · last request")
    expect(dialogs).toHaveLength(3)
    await click("Active 2s")
    expect(dialogs).toHaveLength(4)
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
    expect(frames[0]).toContain("Reported cache reuse 90%")
    expect(frames[0]).not.toContain("Active wall time")
    expect(frames[1]).toContain("Active wall time 2s")
    expect(frames[1]).not.toContain("Reported cache reuse")
    expect(frames[0]).toContain("Close")
    expect(frames[1]).toContain("Close")
  } finally {
    cleanup()
    app.renderer.destroy()
  }
})
