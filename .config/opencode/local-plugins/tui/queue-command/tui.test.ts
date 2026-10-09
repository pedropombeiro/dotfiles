import { expect, mock, test } from "bun:test"

// OpenCode supplies this module at runtime; standalone Bun tests cannot load it.
mock.module("@opencode/plugin/tui", () => ({ Plugin: { define: (value: unknown) => value } }))

type Command = { slash: { name: string; arguments: boolean }; run: (input?: string) => Promise<void> }

test("registers /queue after the app slot renders and queues into the current session", async () => {
  const plugin = (await import("./tui")).default
  const layers: Array<{ mode: string; commands: Command[] }> = []
  const prompts: unknown[] = []
  const toasts: unknown[] = []
  let rendering = false
  let render: (() => null) | undefined
  const cleanup = () => {}
  const result = plugin.setup({
    client: { session: { prompt: async (request: unknown) => void prompts.push(request) } },
    keymap: {
      layer(factory: () => (typeof layers)[number]) {
        if (!rendering) throw new Error("Keymap.Provider is missing")
        layers.push(factory())
      },
    },
    ui: {
      router: { current: () => ({ type: "session", sessionID: "ses_abc" }) },
      toast: { show: (toast: unknown) => void toasts.push(toast) },
      slot(claim: { append: string; render: () => null }) {
        expect(claim.append).toBe("app")
        render = claim.render
        return cleanup
      },
    },
  })
  expect(result).toBe(cleanup)
  expect(layers).toHaveLength(0)
  rendering = true
  expect(render!()).toBeNull()
  expect(layers[0]!.mode).toBe("global")
  const command = layers[0]!.commands[0]!
  expect(command.slash).toEqual({ name: "queue", arguments: true })

  await command.run("next step")
  expect(prompts).toEqual([{ sessionID: "ses_abc", text: "next step", delivery: "queue", resume: true }])
  expect(toasts).toHaveLength(1)
})
