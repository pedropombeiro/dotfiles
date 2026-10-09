/** @jsxImportSource @opentui/solid */
import { Plugin } from "@opencode/plugin/tui"
import type { PanelInput } from "@opencode/plugin/tui/context"
import type { BoxRenderable } from "@opentui/core"
import { createEffect, createMemo, createSignal, For, onCleanup, onMount, Show } from "solid-js"
import { history } from "./src/history"
import { aggregate, descendants, measure, type Message } from "./src/metrics"
import { duration, fit, percent, segments } from "./src/format"

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
            <text fg={context.theme.text.muted}>{store.get(props.sessionID).loading ? "Loading history…" : "Partial history"}</text>
          </Show>
          <Show when={value().own.compactions.length}>
            <text fg={context.theme.text.muted}>Compactions {value().own.completed.length} · {value().own.compactions.at(-1)?.status}</text>
          </Show>
          <Show when={value().own.completed.at(-1)}>{(compact) => <text fg={context.theme.text.muted}>Last started {duration(Math.max(0, now() - compact().time.created))} ago</text>}</Show>
          <Show when={value().own.latest?.percent !== undefined}>
            <text fg={context.theme.text.muted}>Cache {percent(value().own.latest?.percent)} · last request</text>
          </Show>
          <Show when={value().total.cache.percent !== undefined}>
            <text fg={context.theme.text.muted}>Cache {percent(value().total.cache.percent)} · incl. children</text>
          </Show>
          <Show when={value().total.active >= 1000}>
            <text fg={context.theme.text.muted}>Active {duration(value().total.active)} · incl. children</text>
            <text fg={context.theme.text.muted}>Model {duration(value().total.modelTime)} · tools {duration(value().total.toolTime)}</text>
          </Show>
          <text fg={context.theme.text.muted} onMouseUp={() => context.ui.panel.open("metrics.details")}>/session-metrics</text>
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
        return segments(data.own, data.total.active)
      })
      const desired = () => Bun.stringWidth(items().join(" · "))
      return <Show when={desired() > 0}>
        <box width={desired()} flexShrink={100} minWidth={0} height={1} overflow="hidden"
          onSizeChange={function (this: BoxRenderable) { const size = this.width; queueMicrotask(() => resize(size)) }}>
          <text wrapMode="none" fg={context.theme.text.muted}>{fit(items(), width())}</text>
        </box>
      </Show>
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
        <text fg={context.theme.text.base}><b>Session metrics</b> · {children() ? "including descendants" : "selected session"}</text>
        <text fg={context.theme.text.muted}>c scope · r refresh · f fullscreen · esc close</text>
        <scrollbox flexGrow={1} minHeight={0} scrollX={false}>
          <box gap={1} flexShrink={0}>
            <text fg={context.theme.text.base}>Active wall time {duration(total().active)}{"\n"}Model wall time {duration(total().modelTime)}{"\n"}Tool wall time {duration(total().toolTime)}{"\n"}Delegation wait {duration(total().delegateTime)}{"\n"}Summed execution {duration(total().summed)}</text>
            <text fg={context.theme.text.muted}>Recorded intervals, not billing time. Overlaps are merged for wall time. Summed execution excludes subagent delegation waits. Tool durations may include permission/question waits. Earlier retry attempts and compaction generation time may be absent.</text>
            <text fg={context.theme.text.base}>Reported cache reuse {percent(total().cache.percent)}{"\n"}Read {total().cache.read.toLocaleString()} · write {total().cache.write.toLocaleString()} tokens{"\n"}Input coverage {total().cache.reported}/{total().cache.requests} completed requests</text>
            <text fg={context.theme.text.muted}>Reuse = cache reads / (uncached input + cache reads + cache writes). Providers can omit cache counters, which OpenCode normalizes to zero. Zero-only histories are unavailable; mixed-provider totals may understate reuse.</text>
            <For each={selected()}>{(value) => <box gap={0} flexShrink={0}>
              <text fg={context.theme.text.base}><b>{value.session.title ?? value.session.id}</b></text>
              <text fg={context.theme.text.muted}>Active {duration(value.active)} · model {duration(value.modelTime)} · tools {duration(value.toolTime)}{value.partial ? " · partial timing" : ""}</text>
              <text fg={context.theme.text.muted}>Cache {percent(value.cache.percent)} · {store.get(value.session.id).complete ? "history loaded" : "history incomplete"}{store.get(value.session.id).error ? ` · ${store.get(value.session.id).error}` : ""}</text>
              <text fg={context.theme.text.muted}>Compactions {value.completed.length} · auto {value.completed.filter((message) => message.reason === "auto").length} · manual {value.completed.filter((message) => message.reason === "manual").length}</text>
              <For each={value.compactions}>{(message) => <text fg={context.theme.text.muted} onMouseUp={() => showCompaction(message)}>
                {new Date(message.time.created).toLocaleString()} · {message.reason} · {message.status}{message.status === "completed" ? " · open summary" : message.error ? ` · ${message.error.message}` : ""}
              </text>}</For>
            </box>}</For>
            <text fg={context.theme.text.muted}>Use /compaction-history to select a summary with the keyboard.</text>
          </box>
        </scrollbox>
      </box>
    }
    function showCompaction(message: Message) {
      context.ui.dialog.set({ size: "large", centered: true })
      context.ui.dialog.show(() => <box padding={1} height={Math.max(8, Math.min(30, context.renderer.height - 6))} gap={1}>
        <text fg={context.theme.text.base}><b>{message.reason} compaction · {message.status}</b></text>
        <scrollbox flexGrow={1} minHeight={0} scrollX={false}><text fg={context.theme.text.base}>{message.summary ?? message.error?.message ?? "Compaction in progress"}</text></scrollbox>
        <text fg={context.theme.text.muted}>esc close</text>
      </box>)
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
        const records = summary(route.sessionID)?.total.compactions ?? []
        const message = await context.ui.dialog.select({ title: "Compaction history", options: records.map((item) => ({ title: `${new Date(item.time.created).toLocaleString()} · ${item.reason} · ${item.status}`, value: item })) })
        if (message) showCompaction(message)
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
