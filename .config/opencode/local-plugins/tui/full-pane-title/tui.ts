import type { Plugin } from "@opencode/plugin/tui"
import { execFile } from "node:child_process"
import { homedir } from "node:os"
import { promisify } from "node:util"
import { createEffect } from "solid-js"
import { publisher } from "./src/publish"

export default {
  id: "pedropombeiro.full-pane-title",
  setup(context) {
    const pane = process.env.TMUX_PANE
    if (!process.env.TMUX || !pane) return
    const exec = promisify(execFile)
    const writer = publisher(
      (args) => exec("tmux", args),
      pane,
      async () => {
        if (process.platform === "darwin") {
          await exec(`${homedir()}/.config/tmux/iterm2-subtitle`, [])
        }
      },
    )
    const unregister = context.ui.slot({
      append: "app",
      render: () => {
        createEffect(() => {
          const route = context.ui.router.current()
          const title = route.type === "session" ? context.data.session.get(route.sessionID)?.title : undefined
          writer.update(title)
        })
        return null
      },
    })
    return async () => {
      unregister()
      await writer.close()
    }
  },
} satisfies Plugin.Definition
