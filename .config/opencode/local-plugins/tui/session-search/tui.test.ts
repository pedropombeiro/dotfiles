import { expect, mock, test } from "bun:test"

// OpenCode supplies this module at runtime; standalone Bun tests cannot load it.
mock.module("@opencode/plugin/tui", () => ({ Plugin: { define: (value: unknown) => value } }))

type Command = { id: string; bind: string; palette: boolean; slash: { name: string; arguments: boolean }; run: (input?: string) => Promise<void> }

test("registers a palette command that replaces /search-session", async () => {
  const plugin = (await import("./tui")).default
  const layers: Array<{ mode: string; commands: Command[] }> = []
  const prompts: unknown[] = []
  let render: (() => null) | undefined
  plugin.setup({
    keymap: { layer: (factory: () => (typeof layers)[number]) => void layers.push(factory()) },
    ui: {
      toast: { show: () => {} },
      dialog: {
        prompt: async (input: unknown) => {
          prompts.push(input)
          return "  "
        },
      },
      slot(claim: { append: string; render: () => null }) {
        expect(claim.append).toBe("app")
        render = claim.render
        return () => {}
      },
    },
  })
  expect(layers).toHaveLength(0)
  expect(render!()).toBeNull()
  const command = layers[0]!.commands[0]!
  expect(layers[0]!.mode).toBe("global")
  expect(command.bind).toBe("<leader>f")
  expect(command.palette).toBe(true)
  expect(command.slash).toEqual({ name: "search-session", arguments: true })

  // Without arguments, it asks for the query and stops when it's blank.
  await command.run()
  expect(prompts).toHaveLength(1)
})
