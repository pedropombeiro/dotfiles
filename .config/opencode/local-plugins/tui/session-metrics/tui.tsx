/** @jsxImportSource @opentui/solid */
import { Plugin } from "@opencode/plugin/tui"
import type { PanelInput } from "@opencode/plugin/tui/context"
import type { BoxRenderable } from "@opentui/core"
import { createEffect, createMemo, createSignal, For, onCleanup, onMount, Show } from "solid-js"
import { history } from "./src/history"
import { aggregate, descendants, measure, type Message } from "./src/metrics"
import { CACHE_NOTE, duration, fit, join, percent, segments, TIMING_NOTE, type Indicator } from "./src/format"

export default Plugin.define({
  id: "pedropombeiro.session-metrics",
  setup(context) {
    const [version, update] = createSignal(0)
    const [now, clock] = createSignal(Date.now())
    const [mounted, sidebar] = createSignal<Record<string, number>>({})
    const controller = new AbortController()
    const store = history({
      session: (id) => context.client.session.get({ sessionID: id }, { signal: controller.signal }),
      messages: (id, cursor) => context.client.message.list({ sessionID: id, limit: 100, ...(cursor ? { cursor } : { order: "desc" as const }) }, { signal: controller.signal }),
      children: (id, cursor) => context.client.session.list({ parentID: id, limit: 100, ...(cursor ? { cursor } : { order: "asc" as const }) }, { signal: controller.signal }),
    }, () => update((value) => value + 1))
    const refs = new Map<string, number>()
    const measured = new Map<string, { revision: number; time: number; model?: string; value: ReturnType<typeof measure> }>()
    const trees = new Map<string, Promise<void>>()
    const dirty = new Set<string>()
    const timers = new Map<string, ReturnType<typeof setTimeout>>()
    let disposed = false

    const refresh = (id: string) => {
      if (disposed) return
      if (trees.has(id)) { dirty.add(id); return }
      const task = store.tree(id).catch((error: unknown) => {
        store.get(id).error = error instanceof Error ? error.message : String(error)
        if (!disposed) update((value) => value + 1)
      }).finally(() => {
        trees.delete(id)
        if (dirty.delete(id) && refs.has(id)) refresh(id)
      })
      trees.set(id, task)
    }
    const acquire = (id: string) => {
      refs.set(id, (refs.get(id) ?? 0) + 1)
      refresh(id)
      return () => {
        const count = (refs.get(id) ?? 1) - 1
        if (count) refs.set(id, count)
        else refs.delete(id)
      }
    }
    const sessions = () => {
      version()
      const all = new Map(store.entries().flatMap(([, entry]) => entry.session ? [[entry.session.id, entry.session] as const] : []))
      for (const session of context.data.session.list()) all.set(session.id, session)
      return [...all.values()]
    }
    const values = (id: string) => {
      const revision = version()
      const all = sessions()
      return descendants(id, all).flatMap((key) => {
        const session = all.find((item) => item.id === key)
        if (!session) return []
        const running = context.data.session.status(key) === "running"
        const time = running ? now() : 0
        const model = session.model ? `${session.model.providerID}/${session.model.id}` : undefined
        const cached = measured.get(key)
        if (cached?.revision === revision && cached.time === time && cached.model === model) return [cached.value]
        const records = new Map(store.get(key).records)
        for (const message of context.data.session.message.list(key)) records.set(message.id, message)
        const value = measure(session, [...records.values()], now(), running)
        measured.set(key, { revision, time, model, value })
        return [value]
      })
    }
    const summary = (id: string) => {
      const list = values(id)
      const own = list.find((value) => value.session.id === id)
      if (!own) return
      return { own, list, total: aggregate(list), partial: list.some((value) => !store.get(value.session.id).complete || !!store.get(value.session.id).error) }
    }

    function Sidebar(props: { sessionID: string }) {
      const id = props.sessionID
      const data = createMemo(() => summary(props.sessionID))
      onMount(() => sidebar((state) => ({ ...state, [id]: (state[id] ?? 0) + 1 })))
      onCleanup(() => sidebar((state) => ({ ...state, [id]: Math.max(0, (state[id] ?? 1) - 1) })))
      createEffect(() => onCleanup(acquire(props.sessionID)))
      return <Show when={data()}>{(value) => (
        <box gap={0} flexShrink={0}>
          <text fg={context.theme.text.base} onMouseUp={() => context.ui.panel.open("metrics.details")}><b>Session metrics</b></text>
          <Show when={store.get(props.sessionID).loading || value().partial}>
            <text fg={store.get(props.sessionID).loading ? context.theme.text.muted : context.theme.text.feedback.warning.base}>{store.get(props.sessionID).loading ? "Loading history…" : "Partial history"}</text>
          </Show>
          <Show when={value().own.compactions.length}>
            <text fg={context.theme.text.muted} onMouseUp={() => openIndicator("compaction", id)}>Compactions <span style={{ fg: context.theme.text.base }}><b>{value().own.completed.length}</b></span> · {value().own.compactions.at(-1)?.status}</text>
          </Show>
          <Show when={value().own.completed.at(-1)}>{(compact) => <text fg={context.theme.text.muted} onMouseUp={() => openIndicator("compaction", id)}>Last started {duration(Math.max(0, now() - compact().time.created))} ago</text>}</Show>
          <Show when={value().own.latest?.percent !== undefined}>
            <text fg={context.theme.text.muted} onMouseUp={() => openIndicator("cache", id)}>Cache <span style={{ fg: context.theme.text.base }}><b>{percent(value().own.latest?.percent)}</b></span> · last request</text>
          </Show>
          <Show when={value().total.cache.percent !== undefined}>
            <text fg={context.theme.text.muted} onMouseUp={() => openIndicator("cache", id)}>Cache <span style={{ fg: context.theme.text.base }}><b>{percent(value().total.cache.percent)}</b></span> · incl. children</text>
          </Show>
          <Show when={value().total.active >= 1000}>
            <text fg={context.theme.text.muted} onMouseUp={() => openIndicator("timing", id)}>Active <span style={{ fg: context.theme.text.base }}><b>{duration(value().total.active)}</b></span> · incl. children</text>
            <text fg={context.theme.text.muted} onMouseUp={() => openIndicator("timing", id)}>Model <span style={{ fg: context.theme.text.base }}><b>{duration(value().total.modelTime)}</b></span> · tools <span style={{ fg: context.theme.text.base }}><b>{duration(value().total.toolTime)}</b></span></text>
          </Show>
        </box>
      )}</Show>
    }

    function Footer(props: { sessionID?: string }) {
      createEffect(() => {
        if (props.sessionID) onCleanup(acquire(props.sessionID))
      })
      const [width, resize] = createSignal(0)
      const items = createMemo(() => {
        if (!props.sessionID || mounted()[props.sessionID] || context.options.footer === false) return []
        const data = summary(props.sessionID)
        if (!data) return []
        return segments(data.total.active)
      })
      const desired = () => Bun.stringWidth(join(items()))
      return <Show when={desired() > 0}>
        <box width={desired()} flexShrink={100} minWidth={0} height={1} overflow="hidden" flexDirection="row"
          onSizeChange={function (this: BoxRenderable) { const size = this.width; queueMicrotask(() => resize(size)) }}>
          <For each={fit(items(), width())}>{(item, index) => <>
            <Show when={index() > 0}><text wrapMode="none" flexShrink={0} fg={context.theme.text.muted}>{" · "}</text></Show>
            <text wrapMode="none" flexShrink={0} fg={context.theme.text.muted} onMouseUp={() => props.sessionID && openIndicator(item.kind, props.sessionID)}>{item.text}</text>
          </>}</For>
        </box>
      </Show>
    }

    function MetricSummary(props: { total: ReturnType<typeof aggregate>; kind: "timing" | "cache" }) {
      const rows = () => props.kind === "timing" ? [
        ["Active wall time", duration(props.total.active)],
        ["Model wall time", duration(props.total.modelTime)],
        ["Tool wall time", duration(props.total.toolTime)],
        ["Delegation wait", duration(props.total.delegateTime)],
        ["Summed execution", duration(props.total.summed)],
      ] : [
        ["Reported cache reuse", percent(props.total.cache.percent)],
        ["Read tokens", props.total.cache.read.toLocaleString()],
        ["Write tokens", props.total.cache.write.toLocaleString()],
        ["Input coverage", `${props.total.cache.reported}/${props.total.cache.requests} completed requests`],
      ]
      return <box flexShrink={0} gap={1}>
        <text fg={context.theme.text.base}><b>{props.kind === "timing" ? "Timing" : "Cache reuse"}</b></text>
        <box flexShrink={0}>
          <For each={rows()}>{([label, value]) => <text fg={context.theme.text.muted}>
            {label}{" "}<span style={{ fg: context.theme.text.base }}><b>{value}</b></span>
          </text>}</For>
        </box>
        <text fg={context.theme.text.muted}><b>How to read this</b>{"\n"}{props.kind === "timing" ? TIMING_NOTE : CACHE_NOTE}</text>
      </box>
    }

    function Panel(props: { panel: PanelInput }) {
      const [children, scope] = createSignal(true)
      const data = createMemo(() => summary(props.panel.sessionID))
      const selected = createMemo(() => children() ? data()?.list ?? [] : data()?.own ? [data()!.own] : [])
      const total = createMemo(() => aggregate(selected()))
      createEffect(() => onCleanup(acquire(props.panel.sessionID)))
      context.keymap.layer(() => ({ commands: [
        { bind: "c", title: "Toggle descendants", run: () => scope((value) => !value) },
        { bind: "r", title: "Refresh metrics", run: () => refresh(props.panel.sessionID) },
        { bind: "f", title: "Toggle fullscreen", run: props.panel.toggleFullscreen },
        { bind: "escape", title: "Close metrics", run: props.panel.close },
      ] }))
      return <box flexGrow={1} minHeight={0} padding={1} gap={1}>
        <text fg={context.theme.text.base}><b>Session metrics</b><span style={{ fg: context.theme.text.muted }}> · {children() ? "including descendants" : "selected session"}</span></text>
        <text fg={context.theme.text.muted}><b>c</b> scope · <b>r</b> refresh · <b>f</b> fullscreen · <b>esc</b> close</text>
        <scrollbox flexGrow={1} minHeight={0} scrollX={false}>
          <box gap={1} flexShrink={0}>
            <MetricSummary total={total()} kind="timing" />
            <MetricSummary total={total()} kind="cache" />
            <text fg={context.theme.text.base}><b>By session</b></text>
            <For each={selected()}>{(value) => <box gap={0} flexShrink={0}>
              <text fg={context.theme.text.base}><b>{value.session.title ?? value.session.id}</b></text>
              <text fg={context.theme.text.muted}>Active <span style={{ fg: context.theme.text.base }}><b>{duration(value.active)}</b></span> · model <span style={{ fg: context.theme.text.base }}><b>{duration(value.modelTime)}</b></span> · tools <span style={{ fg: context.theme.text.base }}><b>{duration(value.toolTime)}</b></span></text>
              <Show when={value.partial}><text fg={context.theme.text.feedback.warning.base}>Partial timing</text></Show>
              <text fg={context.theme.text.muted}>Cache <span style={{ fg: context.theme.text.base }}><b>{percent(value.cache.percent)}</b></span> · {store.get(value.session.id).complete ? "history loaded" : "history incomplete"}</text>
              <Show when={store.get(value.session.id).error}>{(error) => <text fg={context.theme.text.feedback.error.base}>{error()}</text>}</Show>
              <text fg={context.theme.text.muted}>Compactions <span style={{ fg: context.theme.text.base }}><b>{value.completed.length}</b></span> · auto <b>{value.completed.filter((message) => message.reason === "auto").length}</b> · manual <b>{value.completed.filter((message) => message.reason === "manual").length}</b></text>
              <For each={value.compactions}>{(message) => <text fg={message.error ? context.theme.text.feedback.error.base : context.theme.text.muted} onMouseUp={() => showCompaction(message)}>
                {new Date(message.time.created).toLocaleString()} · {message.reason} · {message.status}{message.status === "completed" ? " · open summary" : message.error ? ` · ${message.error.message}` : ""}
              </text>}</For>
            </box>}</For>
            <text fg={context.theme.text.muted}>Use /compaction-history to select a summary with the keyboard.</text>
          </box>
        </scrollbox>
      </box>
    }
    // A regular Close button for custom dialogs. Escape still closes them, and
    // Enter activates the button, as in the forge status dialog.
    function CloseRow(props: { hint?: string }) {
      const close = () => context.ui.dialog.clear()
      context.keymap.layer(() => ({ mode: "modal", commands: [{ bind: "return", title: "Close dialog", run: close }] }))
      return <box height={1} flexShrink={0} flexDirection="row" justifyContent="space-between">
        <text fg={context.theme.text.muted}>{props.hint ?? ""}</text>
        <box paddingLeft={1} paddingRight={1} flexShrink={0} backgroundColor={context.theme.background.action.primary.focused} onMouseUp={close}>
          <text wrapMode="none" fg={context.theme.text.action.primary.focused}>Close</text>
        </box>
      </box>
    }

    function showCompaction(message: Message) {
      context.ui.dialog.set({ size: "large", centered: true })
      context.ui.dialog.show(() => <box padding={1} height={Math.max(8, Math.min(30, context.renderer.height - 6))} gap={1}>
        <text fg={context.theme.text.base}><b>{message.reason} compaction · {message.status}</b></text>
        <scrollbox flexGrow={1} minHeight={0} scrollX={false}><text fg={context.theme.text.base}>{message.summary ?? message.error?.message ?? "Compaction in progress"}</text></scrollbox>
        <CloseRow />
      </box>)
    }

    const closeAction = { bind: "ctrl+w", title: "Close", side: "right" as const, selection: "none" as const, onTrigger: () => context.ui.dialog.clear() }

    async function showCompactionHistory(sessionID: string) {
      const records = summary(sessionID)?.total.compactions ?? []
      if (!records.length) return context.ui.toast.show({ message: "No compactions in this session yet", variant: "info" })
      const message = await context.ui.dialog.select({ title: "Compaction history", actions: [closeAction], options: records.map((item) => ({ title: `${new Date(item.time.created).toLocaleString()} · ${item.reason} · ${item.status}`, value: item })) })
      if (message) showCompaction(message)
    }

    function Detail(props: { kind: "cache" | "timing"; sessionID: string }) {
      const data = createMemo(() => summary(props.sessionID))
      createEffect(() => onCleanup(acquire(props.sessionID)))
      const timing = props.kind === "timing"
      return <box padding={1} height={Math.max(8, Math.min(24, context.renderer.height - 6))} gap={1}>
        <text fg={context.theme.text.base}><b>{timing ? "Session timing" : "Cache reuse"}</b> · including descendants</text>
        <scrollbox flexGrow={1} minHeight={0} scrollX={false}>
          <Show when={data()} fallback={<text fg={context.theme.text.muted}>Loading…</text>}>{(value) => (
            <box gap={1} flexShrink={0}>
               <MetricSummary total={value().total} kind={props.kind} />
               <Show when={value().list.length > 1}>
                 <text fg={context.theme.text.base}><b>By session</b></text>
                 <For each={value().list}>{(item) => <box flexShrink={0}>
                   <text fg={context.theme.text.base}><b>{item.session.title ?? item.session.id}</b></text>
                   <text fg={context.theme.text.muted}>
                     {timing ? `Active ${duration(item.active)} · model ${duration(item.modelTime)} · tools ${duration(item.toolTime)}` : `Cache ${percent(item.cache.percent)}`}
                   </text>
                 </box>}</For>
               </Show>
               <Show when={value().partial}><text fg={context.theme.text.feedback.warning.base}><b>Partial history</b>{"\n"}Some sessions are still loading or failed to load.</text></Show>
            </box>
          )}</Show>
        </scrollbox>
        <CloseRow hint="/session-metrics opens the full panel" />
      </box>
    }

    function openIndicator(kind: Indicator, sessionID: string) {
      if (kind === "compaction") return void showCompactionHistory(sessionID)
      context.ui.dialog.set({ size: "large", centered: true })
      context.ui.dialog.show(() => <Detail kind={kind} sessionID={sessionID} />)
    }

    context.ui.slot({ append: "sidebar.content", render: (props) => <Sidebar sessionID={props.sessionID} /> })
    context.ui.slot({ append: "prompt.footer.status", render: (props) => <Footer sessionID={props.sessionID} /> })
    context.ui.slot({ append: "session.panel", render: (props) => <Show when={props.name === "metrics.details"}><Panel panel={props} /></Show> })
    context.ui.slot({ append: "app", render: () => {
      context.keymap.layer(() => ({ mode: "global", commands: [
      { id: "metrics.details", title: "Show session metrics", group: "Session", palette: true, slash: { name: "session-metrics" }, run: () => {
        if (!context.ui.panel.open("metrics.details")) context.ui.toast.show({ message: "Open a session first", variant: "info" })
      } },
      { id: "metrics.compactions", title: "Show compaction history", group: "Session", palette: true, slash: { name: "compaction-history" }, run: async () => {
        const route = context.ui.router.current()
        if (route.type !== "session") return
        await showCompactionHistory(route.sessionID)
      } },
      ] }))
      return null
    } })

    const stop = context.data.listen(({ details }) => {
      if (!details.type.startsWith("session.")) return
      const event = details as { type: string; data?: { sessionID?: string; id?: string }; created?: number }
      const id = event.data?.sessionID ?? (event.type === "session.created" ? event.data?.id : undefined)
      if (!id) return
      if (event.type === "session.revert.committed") store.reset(id)
      const relevant = [...refs.keys()].filter((root) => descendants(root, sessions()).includes(id))
      if (!relevant.length && event.type !== "session.created") return
      if (/session\.(execution\.|compaction\.|created|revert\.|model\.)/.test(event.type)) {
        for (const root of relevant.length ? relevant : refs.keys()) dirty.add(root)
      }
      const timer = timers.get(id)
      if (timer) return
      timers.set(id, setTimeout(() => {
        timers.delete(id)
        if (disposed) return
        store.overlay(id, context.data.session.message.list(id))
        for (const root of [...dirty]) {
          dirty.delete(root)
          if (refs.has(root)) refresh(root)
        }
      }, 300))
    })
    const tick = setInterval(() => {
      if (refs.size) clock(Date.now())
    }, 1000)
    const reconcile = setInterval(() => { for (const root of refs.keys()) refresh(root) }, 30_000)
    return () => {
      disposed = true
      controller.abort()
      stop()
      clearInterval(tick)
      clearInterval(reconcile)
      for (const timer of timers.values()) clearTimeout(timer)
      store.dispose()
    }
  },
})
