/** @jsxImportSource @opentui/solid */
// OpenCode loads this CLI entry point automatically because the server
// entry point in index.ts is configured in opencode.json. The status comes
// from the server over RPC, because the background service is the process
// that exports telemetry.
import { Plugin } from "@opencode/plugin/tui"
import { createMemo, Show } from "solid-js"
import { OtelStatusRpc } from "./src/rpc"
import { describeStatus, indicatorLabel, indicatorState, type IndicatorState, type OtelStatus } from "./src/status"

const REFRESH_MS = 30_000
const TITLE = "OTEL collector"

interface View {
  loaded: boolean
  status?: OtelStatus
  now: number
}

function describeCheck(status: OtelStatus): string {
  if (status.state === "reachable") return `Reachable (${status.latencyMs ?? "?"}ms)`
  if (status.state === "unreachable") return `Unreachable: ${status.error ?? "unknown error"}`
  if (status.state === "disabled") return "No OTEL endpoint is configured"
  return "Check in progress"
}

export default Plugin.define({
  id: "pedropombeiro.otel-status-cli",
  setup(context) {
    const otel = context.client.rpc(OtelStatusRpc)
    const location = () => context.location ?? context.data.location.default()
    const [view, update] = context.storage.memory<View>("view", { initial: { loaded: false, now: Date.now() } })

    const apply = (status: OtelStatus | undefined) =>
      update((draft) => {
        draft.loaded = true
        draft.status = status
        draft.now = Date.now()
      })

    // A failed call means the server plugin is not loaded or not responding,
    // which the indicator shows as unknown.
    const refresh = async () => {
      try {
        apply((await otel.status({}, { location: location() })) as OtelStatus)
      } catch {
        apply(undefined)
      }
    }

    const current = (): IndicatorState => (view.loaded ? indicatorState(view.status, view.now) : "checking")

    const color = (state: IndicatorState) => {
      const text = context.theme.text
      if (state === "reachable") return text.feedback.success.base
      if (state === "unreachable") return text.feedback.error.base
      return text.muted
    }

    function Indicator() {
      const state = createMemo(current)
      return (
        <Show when={state() !== "disabled"}>
          <text wrapMode="none" flexShrink={0} fg={color(state())}>
            {indicatorLabel(state())}
          </text>
        </Show>
      )
    }

    async function check() {
      try {
        const status = (await otel.check({}, { location: location() })) as OtelStatus
        apply(status)
        context.ui.toast.show({
          title: TITLE,
          message: describeCheck(status),
          variant: status.state === "reachable" ? "success" : "error",
        })
      } catch (error) {
        apply(undefined)
        const message = error instanceof Error ? error.message : String(error)
        context.ui.toast.show({ title: TITLE, message: `Status check failed: ${message}`, variant: "error" })
      }
    }

    async function showDetails() {
      await refresh()
      const message = describeStatus(view.status, Date.now())
      if (!view.status || view.status.state === "disabled") {
        await context.ui.dialog.alert({ title: TITLE, message })
        return
      }
      const confirmed = await context.ui.dialog.confirm({
        title: TITLE,
        message,
        label: { confirm: "Check now", cancel: "Close" },
      })
      if (confirmed) await check()
    }

    const stops = [
      context.ui.slot({ append: "home.footer.status", render: () => <Indicator /> }),
      context.ui.slot({ append: "prompt.footer.status", render: () => <Indicator /> }),
      context.ui.slot({
        append: "app",
        render: () => {
          context.keymap.layer(() => ({
            mode: "global",
            commands: [
              {
                id: "otel.status",
                title: "Show OTEL collector status",
                group: "OTEL",
                palette: true,
                slash: { name: "otel" },
                run: showDetails,
              },
            ],
          }))
          return null
        },
      }),
      otel.events.on("changed", (event) => apply(event.data as unknown as OtelStatus)),
    ]

    void refresh()
    // Events are live-only, so polling recovers from missed events after a
    // reconnect and lets a stale result age into the unknown state.
    const timer = setInterval(() => void refresh(), REFRESH_MS)

    return () => {
      clearInterval(timer)
      for (const stop of stops) stop()
    }
  },
})
