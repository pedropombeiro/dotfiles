import { Plugin } from "@opencode/plugin/tui"
import { toggleTail } from "./src/tail"

export default Plugin.define({
  id: "pedropombeiro.tail-latest-temp",
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
              id: "pedropombeiro.tail-latest-temp",
              title: "Toggle latest temp-file tail",
              group: "Tools",
              bind: "<leader>o",
              palette: true,
              async run() {
                if (busy) return
                busy = true
                try {
                  context.ui.toast.show(await toggleTail())
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
