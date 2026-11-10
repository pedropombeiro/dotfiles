import { Plugin } from "@opencode/plugin/tui"
import { toggleTail } from "./src/tail"
import { preferredFile } from "./src/session"

export default Plugin.define({
  id: "pedropombeiro.temp-file-tail",
  setup(context) {
    let busy = false
    return context.ui.slot({
      append: "app",
      render: () => {
        // Register during rendering so older V2 releases can resolve Keymap.Provider.
        context.keymap.layer(() => ({
          mode: "global",
          commands: [
            {
              id: "pedropombeiro.temp-file-tail",
              title: "Toggle temp-file tail",
              group: "Tools",
              bind: "<leader>o",
              palette: true,
              async run() {
                if (busy) return
                busy = true
                try {
                  const route = context.ui.router.current()
                  context.ui.toast.show(await toggleTail(process.env, undefined, (directory) =>
                    preferredFile(directory, route.type === "session" ? route.sessionID : undefined, {
                      messages: (id, cursor) => context.client.message.list({ sessionID: id, limit: 100, ...(cursor ? { cursor } : { order: "desc" as const }) }),
                      children: (id, cursor) => context.client.session.list({ parentID: id, limit: 100, ...(cursor ? { cursor } : { order: "asc" as const }) }),
                    }),
                  ))
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
