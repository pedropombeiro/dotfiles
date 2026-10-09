import { expect, mock, test } from "bun:test"

// OpenCode supplies this module at runtime; standalone Bun tests cannot load it.
mock.module("@opencode/plugin/tui", () => ({ Plugin: { define: (value: unknown) => value } }))

test("registers commands only after the app slot is rendered", async () => {
  const plugin = (await import("./tui")).default
  const layers: Array<{ mode: string; commands: Array<{ bind: string; slash: { name: string } }> }> = []
  let rendering = false
  let render: (() => null) | undefined
  const cleanup = () => {}
  const result = plugin.setup({
    keymap: {
      layer(factory: () => (typeof layers)[number]) {
        if (!rendering) throw new Error("Keymap.Provider is missing")
        layers.push(factory())
      },
    },
    ui: {
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
  expect(layers).toHaveLength(1)
  expect(layers[0]!.mode).toBe("global")
  expect(layers[0]!.commands[0]!.bind).toBe("shift+tab")
  expect(layers[0]!.commands[0]!.slash.name).toBe("permission-mode")
})
