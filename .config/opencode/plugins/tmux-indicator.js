export const TmuxIndicator = async ({ $ }) => {
  const tmux = process.env.TMUX
  if (!tmux) return {}

  const tmuxPane = process.env.TMUX_PANE
  if (!tmuxPane) return {}

  let windowId
  let active = false
  let startupGrace = true
  setTimeout(() => { startupGrace = false }, 3000)

  const getWindowId = async () => {
    if (!windowId) {
      windowId = (await $`tmux display-message -t ${tmuxPane} -p '#{window_id}'`.quiet().text()).trim()
    }
    return windowId
  }

  const activate = async () => {
    if (active || startupGrace) return
    const wid = await getWindowId()
    await $`tmux set-option -w -t ${wid} @opencode-waiting 1`.quiet()
    active = true
  }

  const deactivate = async () => {
    if (!active) return
    const wid = await getWindowId()
    await $`tmux set-option -w -u -t ${wid} @opencode-waiting`.nothrow().quiet()
    active = false
  }

  return {
    event: async ({ event }) => {
      if (event.type === "permission.asked") {
        await activate()
      } else if (
        event.type === "permission.replied" ||
        event.type === "session.idle" ||
        (event.type === "session.status" && event.properties.status.type === "busy")
      ) {
        await deactivate()
      }
    },
    "tool.execute.before": async (input, _output) => {
      if (input.tool === "question") await activate()
    },
    "tool.execute.after": async (input, _output) => {
      if (input.tool === "question") await deactivate()
    },
  }
}
