import { Plugin } from "@opencode/plugin/tui"
import { configPath, override, toggle } from "./src/config"

export default Plugin.define({
  id: "pedropombeiro.permission-mode",
  setup(context) {
    let busy = false
    return context.ui.slot({
      append: "app",
      render: () => {
        // Register during rendering so v2.0.22 can resolve Keymap.Provider.
        // Without a global mode, the layer lives in the base mode and the
        // slash list, which shows only reachable commands, leaves it out.
        context.keymap.layer(() => ({
          mode: "global",
          commands: [
            {
              id: "pedropombeiro.permissions.toggle",
              title: "Toggle permission mode",
              group: "Permissions",
              bind: "shift+tab",
              palette: true,
              slash: { name: "permission-mode" },
              async run() {
                if (busy) return
                busy = true
                try {
                  const blocked = override(process.env, process.argv)
                  if (blocked) {
                    context.ui.toast.show({ message: blocked, variant: "warning" })
                    return
                  }
                  const mode = await toggle(configPath())
                  context.ui.toast.show({
                    title: "Global permission mode",
                    message: mode === "prompt" ? "Prompt for approval" : "Auto accept permission requests",
                    variant: mode === "prompt" ? "info" : "warning",
                  })
                } catch (err) {
                  context.ui.toast.show({
                    message: err instanceof Error ? err.message : String(err),
                    variant: "error",
                  })
                } finally {
                  busy = false
                }
              },
            },
          ],
        }))
        return null
      },
    })
  },
})
