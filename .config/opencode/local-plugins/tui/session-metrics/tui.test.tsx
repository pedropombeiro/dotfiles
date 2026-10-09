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
