import { Plugin } from "@opencode/plugin/tui"
import { createEffect } from "solid-js"

const DEFAULT_BIND = "<leader>`"
const MAX_HISTORY = 50

export function resolveBind(value: unknown): string | false {
  if (value === false || value === "none") return false
  if (typeof value === "string" && value.trim().length > 0) return value.trim()
  return DEFAULT_BIND
}

export default Plugin.define({
  id: "pedropombeiro.last-session-tab",
  setup(context) {
    const history: string[] = []
    const bind = resolveBind(context.options?.bind)

    function record(sessionID: string | undefined) {
      if (!sessionID || history[0] === sessionID) return
      const index = history.indexOf(sessionID)
      if (index !== -1) history.splice(index, 1)
      history.unshift(sessionID)
      if (history.length > MAX_HISTORY) history.length = MAX_HISTORY
    }

    function currentTabSessionID(): string | undefined {
      const route = context.ui.router.current()
      const tabs = context.ui.tabs.enabled() ? context.ui.tabs.list() : undefined
      if (route.type !== "session") return undefined
      return (
        tabs?.find((tab) => tab.active)?.sessionID ??
        context.data?.session?.root?.(route.sessionID) ??
        route.sessionID
      )
    }

    return context.ui.slot({
      append: "app",
      render: () => {
        createEffect(() => {
          record(currentTabSessionID())
        })

        // Register during rendering so Keymap.Provider is available.
        context.keymap.layer(() => ({
          mode: "global",
          commands: [
            {
              id: "pedropombeiro.session.tab.last",
              title: "Switch to last session tab",
              group: "Session",
              bind,
              palette: true,
              run() {
                const currentID = currentTabSessionID()
                const tabsEnabled = context.ui.tabs.enabled()
                const openIDs = tabsEnabled
                  ? new Set(context.ui.tabs.list().map((tab) => tab.sessionID))
                  : undefined
                const targetID = history.find(
                  (id) => id !== currentID && (!openIDs || openIDs.has(id)),
                )
                if (!targetID) {
                  context.ui.toast.show({
                    message: "No previous session tab",
                    variant: "info",
                  })
                  return
                }
                if (tabsEnabled) {
                  if (context.ui.tabs.focus(targetID)) record(targetID)
                  return
                }
                context.ui.router.navigate({ type: "session", sessionID: targetID })
                record(targetID)
              },
            },
          ],
        }))
        return null
      },
    })
  },
})
