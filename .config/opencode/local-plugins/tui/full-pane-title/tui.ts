import type { Plugin } from "@opencode/plugin/tui"
import { execFile } from "node:child_process"
import { homedir } from "node:os"
import { promisify } from "node:util"
import { createEffect, createSignal } from "solid-js"
import { attentionTracker, type Attention } from "./src/attention"
import { publisher } from "./src/publish"

export default {
  id: "pedropombeiro.full-pane-title",
  setup(context) {
    const pane = process.env.TMUX_PANE
    if (!process.env.TMUX || !pane) return
    const exec = promisify(execFile)
    const [attention, setAttention] = createSignal<Attention>()
    const tracker = attentionTracker((sessionID) => {
      const root = context.data.session.root(sessionID)
      const route = context.ui.router.current()
      return (route.type === "session" && context.data.session.root(route.sessionID) === root)
        || (context.ui.tabs.enabled() && context.ui.tabs.list().some((tab) => tab.sessionID === root))
    })
    const writer = publisher(
      (args) => exec("tmux", args),
      pane,
      async () => {
        await exec(`${homedir()}/.config/tmux/iterm2-subtitle`, [])
      },
    )
    const stop = context.data.listen(({ details }) => {
      tracker.handle(details)
      setAttention(tracker.state())
    })
    const unregister = context.ui.slot({
      append: "app",
      render: () => {
        createEffect(() => {
          const route = context.ui.router.current()
          const title = route.type === "session" ? context.data.session.get(route.sessionID)?.title : undefined
          writer.update(title, attention())
        })
        return null
      },
    })
    return async () => {
      stop()
      unregister()
      await writer.close()
    }
  },
} satisfies Plugin.Definition
