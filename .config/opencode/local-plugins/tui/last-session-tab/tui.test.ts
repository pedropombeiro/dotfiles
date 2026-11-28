import { expect, mock, test } from "bun:test"

let effect: (() => void) | undefined
mock.module("@opencode/plugin/tui", () => ({ Plugin: { define: (value: unknown) => value } }))
mock.module("solid-js", () => ({
  createEffect: (run: () => void) => {
    effect = run
    run()
  },
}))

type TestCommand = {
  id: string
  title: string
  group: string
  bind: string | false
  palette: boolean
  run: () => void
}

function setupPlugin(options?: Record<string, unknown>) {
  let route: { type: string; sessionID?: string } = { type: "session", sessionID: "session-a" }
  let openTabs = ["session-a", "session-b", "session-c"]
  const roots: Record<string, string> = {}
  const toasts: Array<{ message: string; variant?: string }> = []
  const navigated: Array<{ type: string; sessionID: string }> = []
  let tabsEnabled = true
  let render: (() => null) | undefined
  let layer: { mode: string; commands: TestCommand[] } | undefined
  const cleanup = () => {}

  return {
    cleanup,
    toasts,
    navigated,
    getLayer: () => layer,
    getRoute: () => route,
    setRoute(next: { type: string; sessionID?: string }) {
      route = next
      effect?.()
    },
    setOpenTabs(next: string[]) {
      openTabs = next
    },
    setRoot(childID: string, rootID: string) {
      roots[childID] = rootID
    },
    setTabsEnabled(enabled: boolean) {
      tabsEnabled = enabled
    },
    async init() {
      const plugin = (await import("./tui")).default
      const result = plugin.setup({
        options: options ?? {},
        data: {
          session: {
            root: (id: string) => roots[id] ?? id,
          },
        },
        keymap: {
          layer(factory: () => NonNullable<typeof layer>) {
            layer = factory()
          },
        },
        ui: {
          router: {
            current: () => route,
            navigate(dest: { type: string; sessionID: string }) {
              navigated.push(dest)
              route = dest
              effect?.()
            },
          },
          tabs: {
            enabled: () => tabsEnabled,
            list: () =>
              openTabs.map((sessionID) => ({
                sessionID,
                active:
                  route.type === "session" &&
                  (roots[route.sessionID!] ?? route.sessionID) === sessionID,
              })),
            focus(sessionID: string) {
              if (!tabsEnabled || !openTabs.includes(sessionID)) return false
              route = { type: "session", sessionID }
              effect?.()
              return true
            },
          },
          toast: {
            show(toast: { message: string; variant?: string }) {
              toasts.push(toast)
            },
          },
          slot(claim: { append: string; render: () => null }) {
            expect(claim.append).toBe("app")
            render = claim.render
            return cleanup
          },
        },
      } as never)
      expect(result).toBe(cleanup)
      expect(layer).toBeUndefined()
      expect(render!()).toBeNull()
      expect(layer).toBeDefined()
      return layer!.commands[0]!
    },
  }
}

test("registers default <leader>` shortcut and alternates between the last two session tabs", async () => {
  const harness = setupPlugin()
  const cmd = await harness.init()

  expect( harness.getLayer()!.mode ).toBe("global")
  expect(cmd).toMatchObject({
    id: "pedropombeiro.session.tab.last",
    title: "Switch to last session tab",
    group: "Session",
    bind: "<leader>`",
    palette: true,
  })

  // No previous tab yet when only session-a has been visited.
  cmd.run()
  expect(harness.toasts).toEqual([{ message: "No previous session tab", variant: "info" }])
  expect(harness.getRoute()).toEqual({ type: "session", sessionID: "session-a" })

  // Visit session-b, then alternate A <-> B repeatedly.
  harness.setRoute({ type: "session", sessionID: "session-b" })
  cmd.run()
  expect(harness.getRoute()).toEqual({ type: "session", sessionID: "session-a" })

  cmd.run()
  expect(harness.getRoute()).toEqual({ type: "session", sessionID: "session-b" })

  cmd.run()
  expect(harness.getRoute()).toEqual({ type: "session", sessionID: "session-a" })
})

test("skips closed tabs and falls back to the most recent open tab", async () => {
  const harness = setupPlugin()
  const cmd = await harness.init()

  harness.setRoute({ type: "session", sessionID: "session-b" })
  harness.setRoute({ type: "session", sessionID: "session-c" })
  // Close session-b so only session-a and session-c remain open.
  harness.setOpenTabs(["session-a", "session-c"])

  cmd.run()
  expect(harness.getRoute()).toEqual({ type: "session", sessionID: "session-a" })
})

test("ignores subagent navigation within the same root tab", async () => {
  const harness = setupPlugin()
  harness.setRoot("subagent-b1", "session-b")
  const cmd = await harness.init()

  harness.setRoute({ type: "session", sessionID: "session-b" })
  harness.setRoute({ type: "session", sessionID: "subagent-b1" })

  cmd.run()
  expect(harness.getRoute()).toEqual({ type: "session", sessionID: "session-a" })
})

test("allows overriding or disabling the keybinding via plugin options", async () => {
  const custom = setupPlugin({ bind: "<leader>p" })
  const customCmd = await custom.init()
  expect(customCmd.bind).toBe("<leader>p")

  const disabled = setupPlugin({ bind: "none" })
  const disabledCmd = await disabled.init()
  expect(disabledCmd.bind).toBe(false)

  const disabledBool = setupPlugin({ bind: false })
  const disabledBoolCmd = await disabledBool.init()
  expect(disabledBoolCmd.bind).toBe(false)
})
