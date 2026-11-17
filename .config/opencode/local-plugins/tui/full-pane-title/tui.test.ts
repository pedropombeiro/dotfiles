import { expect, mock, test } from "bun:test"

let effect: (() => void) | undefined
const calls: string[][] = []
mock.module("solid-js", () => ({
  createEffect: (run: () => void) => { effect = run; run() },
  createSignal: () => {
    let value: unknown
    return [() => value, (next: unknown) => { value = next; effect?.() }]
  },
}))
mock.module("node:child_process", () => ({
  execFile: (file: string, args: string[], callback: (error: null, result: string) => void) => {
    calls.push([file, ...args])
    callback(null, "")
  },
}))

test("tracks the displayed session and its complete title, then removes the override", async () => {
  const saved = { TMUX: process.env.TMUX, TMUX_PANE: process.env.TMUX_PANE }
  process.env.TMUX = "/fake/socket,1,0"
  process.env.TMUX_PANE = "%7"
  try {
    const plugin = (await import("./tui")).default
    let route: { type: string; sessionID?: string } = { type: "session", sessionID: "first" }
    const titles: Record<string, string> = { first: "Full title ".repeat(20), second: "Second session" }
    let removed = false
    let stopped = false
    let listen: (event: { details: unknown }) => void = () => {}
    const close = plugin.setup({
      ui: {
        router: { current: () => route },
        tabs: { enabled: () => true, list: () => [{ sessionID: "second" }] },
        slot: ({ render }: { render: () => null }) => { render(); return () => { removed = true } },
      },
      data: {
        session: { get: (id: string) => ({ title: titles[id] }), root: (id: string) => id },
        listen: (handler: typeof listen) => { listen = handler; return () => { stopped = true } },
      },
    } as never)
    titles.first += "renamed"
    effect!()
    route = { type: "session", sessionID: "second" }
    effect!()
    route = { type: "home" }
    effect!()
    listen({ details: { type: "permission.asked", data: { sessionID: "unrelated", id: "ignored" } } })
    listen({ details: { type: "permission.asked", data: { sessionID: "second", id: "request" } } })
    listen({ details: { type: "permission.replied", data: { sessionID: "second", requestID: "request" } } })
    await close!()
    expect(removed).toBe(true)
    expect(stopped).toBe(true)
    expect(calls.filter((args) => args.includes("@opencode-full-title"))).toEqual([
      ["tmux", "set-option", "-p", "-t", "%7", "@opencode-full-title", "Full title ".repeat(20)],
      ["tmux", "set-option", "-p", "-t", "%7", "@opencode-full-title", titles.first],
      ["tmux", "set-option", "-p", "-t", "%7", "@opencode-full-title", titles.second],
      ["tmux", "set-option", "-p", "-u", "-t", "%7", "@opencode-full-title"],
      ["tmux", "set-option", "-p", "-u", "-t", "%7", "@opencode-full-title"],
      ["tmux", "set-option", "-p", "-u", "-t", "%7", "@opencode-full-title"],
      ["tmux", "set-option", "-p", "-u", "-t", "%7", "@opencode-full-title"],
    ])
    expect(calls.filter((args) => args.includes("@opencode-attention") && args.at(-1) === "waiting")).toHaveLength(1)
  } finally {
    for (const [key, value] of Object.entries(saved)) {
      if (value === undefined) delete process.env[key]
      else process.env[key] = value
    }
  }
})
