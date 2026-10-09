import { Plugin } from "@opencode/plugin/tui"
import { queueMessage } from "./src/queue"

export default Plugin.define({
  id: "pedropombeiro.queue-command",
  setup(context) {
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
              id: "pedropombeiro.queue",
              title: "Queue message",
              group: "Session",
              palette: true,
              slash: { name: "queue", arguments: true },
              async run(input?: string) {
                const toast = await queueMessage(input, context.ui.router.current(), (request) =>
                  context.client.session.prompt(request),
                )
                context.ui.toast.show(toast)
              },
            },
          ],
        }))
        return null
      },
    })
  },
})
