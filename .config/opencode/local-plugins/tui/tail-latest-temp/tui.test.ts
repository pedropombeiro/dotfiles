import { expect, mock, test } from "bun:test"

mock.module("@opencode/plugin/tui", () => ({ Plugin: { define: (value: unknown) => value } }))

test("registers the palette command and leader shortcut during app rendering", async () => {
  const plugin = (await import("./tui")).default
  let render: (() => null) | undefined
  let layer: { mode: string; commands: Array<{ id: string; bind: string; palette: boolean }> } | undefined
  const cleanup = () => {}
  expect(plugin.setup({
    keymap: { layer(factory: () => NonNullable<typeof layer>) { layer = factory() } },
    ui: {
      slot(claim: { append: string; render: () => null }) {
        expect(claim.append).toBe("app")
        render = claim.render
        return cleanup
      },
    },
  })).toBe(cleanup)
  expect(layer).toBeUndefined()
  expect(render!()).toBeNull()
  expect(layer!.mode).toBe("global")
  expect(layer!.commands[0]).toMatchObject({
    id: "pedropombeiro.tail-latest-temp", bind: "<leader>o", palette: true,
  })
})
