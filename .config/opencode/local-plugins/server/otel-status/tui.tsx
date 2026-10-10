/** @jsxImportSource @opentui/solid */
// OpenCode loads this CLI entry point automatically because the server
// entry point in index.ts is configured in opencode.json. The status comes
// from the server over RPC, because the background service is the process
// that exports telemetry.
import { Plugin } from "@opencode/plugin/tui"
import { createMemo, createSignal, For, onCleanup, Show } from "solid-js"
import { OtelStatusRpc } from "./src/rpc"
import {
  describeStatus,
  hostWarning,
  indicatorLabel,
  indicatorState,
  indicatorTone,
  type IndicatorState,
  type OtelStatus,
  type Tone,
} from "./src/status"

const REFRESH_MS = 30_000
const WARNING_TOAST_MS = 15_000
const TITLE = "OTEL collector"

interface View {
  loaded: boolean
  status?: OtelStatus
  now: number
  warned: boolean
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
    const [view, update] = context.storage.memory<View>("view", {
      initial: { loaded: false, now: Date.now(), warned: false },
    })

    // Memory storage survives plugin reloads, so the warning toast appears
    // once per terminal session; the footer and /otel keep showing it.
    const apply = (status: OtelStatus | undefined) => {
      const warning = hostWarning(status)
      const notify = warning !== undefined && !view.warned
      update((draft) => {
        draft.loaded = true
        draft.status = status
        draft.now = Date.now()
        if (notify) draft.warned = true
      })
      if (notify)
        context.ui.toast.show({ title: TITLE, message: warning, variant: "warning", duration: WARNING_TOAST_MS })
    }

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

    const tone = (): Tone => (view.loaded ? indicatorTone(view.status, view.now) : "muted")

    const color = (value: Tone) => {
      const text = context.theme.text
      if (value === "muted") return text.muted
      return text.feedback[value].base
    }

    function Indicator() {
      const state = createMemo(current)
      return (
        <Show when={state() !== "disabled"}>
          <text wrapMode="none" flexShrink={0} fg={color(tone())} onMouseUp={() => void showDetails()}>
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
          variant: status.state !== "reachable" ? "error" : hostWarning(status) ? "warning" : "success",
        })
      } catch (error) {
        apply(undefined)
        const message = error instanceof Error ? error.message : String(error)
        context.ui.toast.show({ title: TITLE, message: `Status check failed: ${message}`, variant: "error" })
      }
    }

    function Details() {
      const [height, resize] = createSignal(context.renderer.height)
      const onResize = () => resize(context.renderer.height)
      context.renderer.on("resize", onResize)
      onCleanup(() => context.renderer.off("resize", onResize))
      const [busy, setBusy] = createSignal(false)
      const [active, setActive] = createSignal("close")
      const canCheck = () => !!view.status && view.status.state !== "disabled"
      const close = () => context.ui.dialog.clear()
      const runCheck = async () => {
        if (busy() || !canCheck()) return
        setBusy(true)
        try { await check() } finally { setBusy(false) }
      }
      const toggle = () => setActive((value) => value === "close" && canCheck() && !busy() ? "check" : "close")
      context.keymap.layer(() => ({ mode: "modal", commands: [
        { bind: "tab", title: "Next dialog action", run: toggle },
        { bind: "shift+tab", title: "Previous dialog action", run: toggle },
        { bind: "left", title: "Previous dialog action", run: toggle },
        { bind: "right", title: "Next dialog action", run: toggle },
        { bind: "return", title: "Activate dialog action", run: () => { if (active() === "check") void runCheck(); else close() } },
      ] }))
      return <box height={Math.max(6, Math.min(24, Math.floor(height() * 0.6)))} paddingLeft={2} paddingRight={2} paddingBottom={1} gap={1}>
        <box height={1} flexShrink={0} flexDirection="row" justifyContent="space-between">
          <text fg={context.theme.text.base}><b>{TITLE}</b></text>
          <text fg={context.theme.text.muted} onMouseUp={close}>esc</text>
        </box>
        <scrollbox flexGrow={1} minHeight={0} scrollX={false} contentOptions={{ flexShrink: 0 }}>
          <box gap={1} flexShrink={0}>
            <For each={describeStatus(view.status, view.now).split("\n").filter(Boolean)}>{(line) => {
              const separator = line.indexOf(": ")
              const label = separator < 0 ? undefined : line.slice(0, separator)
              const value = separator < 0 ? line : line.slice(separator + 2)
              const tone = label === "Error" ? "error" : label === "Warning" ? "warning" : "muted"
              return <text fg={color(tone)}>
                <Show when={label} fallback={value}>
                  <b>{label}</b>{"\n"}<span style={{ fg: label === "Status" ? color(indicatorTone(view.status, view.now)) : tone === "muted" ? context.theme.text.base : color(tone) }}>{value}</span>
                </Show>
              </text>
            }}</For>
          </box>
        </scrollbox>
        <box height={1} flexShrink={0} flexDirection="row" justifyContent="flex-end">
          <For each={canCheck() ? ["close", "check"] : ["close"]}>{(action) => {
            const disabled = () => action === "check" && busy()
            const selected = () => active() === action && !disabled()
            return <box paddingLeft={1} paddingRight={1} flexShrink={0}
              backgroundColor={selected() ? context.theme.background.action.primary.focused : undefined}
              onMouseMove={() => { if (!disabled()) setActive(action) }}
              onMouseUp={() => { if (action === "check") void runCheck(); else close() }}>
              <text wrapMode="none" fg={disabled() ? context.theme.text.action.primary.disabled : selected() ? context.theme.text.action.primary.focused : context.theme.text.muted}>
                {action === "close" ? "Close" : busy() ? "Checking…" : "Check now"}
              </text>
            </box>
          }}</For>
        </box>
      </box>
    }

    async function showDetails() {
      await refresh()
      context.ui.dialog.set({ size: "large", centered: true })
      context.ui.dialog.show(() => <Details />)
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
