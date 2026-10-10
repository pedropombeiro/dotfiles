/** @jsxImportSource @opentui/solid */
// OpenCode loads this CLI entry point automatically because the server entry
// point in index.ts is configured in opencode.json. It shows the PRs/MRs of the
// targets that the server stores, and tells the agent about their reviews. It
// reads its options from the server, and `reviewStatus: false` turns it off.
import { Plugin } from "@opencode/plugin/tui"
import type { BoxRenderable } from "@opentui/core"
import { createEffect, createMemo, createSignal, For, on, onCleanup, Show } from "solid-js"
import {
  automatedReview,
  createAutomatedReviewWatcher,
  createNotificationClaim,
  isReviewRunning,
  recordNotification,
  reviewMessage,
  reviewTitle,
  reviewToast,
  type NotifiedLog,
} from "./src/automated-review-watch"
import { exec } from "./src/exec"
import { detailsMessage, footerSegments, responsiveFooterSegments, segmentsWidth, type Tone } from "./src/format"
import { titlePrefix, type ReviewComment, type ReviewRequest } from "./src/forge"
import { Forges, hostsFrom, reference, traitsOf } from "./src/forges"
import {
  createFeedbackWatcher,
  feedbackMessage,
  feedbackToast,
  recordFeedback,
  type FeedbackLog,
} from "./src/human-review-watch"
import { locate } from "./src/locate"
import { createSessionWatch } from "./src/session-watch"
import { createStatusStore, type Lookup } from "./src/store"
import { resolveCliOptions, reviewStatusEnabled } from "./src/options"
import { ForgeSessionRpc } from "./src/rpc"
import { classifyTargets } from "./src/target"

// Cache keys are per session, because sessions sharing a checkout can target
// different PRs/MRs. The title's managed prefix, which holds its references,
// is part of the key so a reference change triggers a new lookup.
interface Key {
  directory: string
  sessionID?: string
  prefix?: string
}
const keyOf = (key: Key) => JSON.stringify([key.directory, key.sessionID ?? "", key.prefix ?? ""])
const parseKey = (key: string): Key => {
  const [directory, sessionID, prefix] = JSON.parse(key) as [string, string, string]
  return { directory, sessionID: sessionID || undefined, prefix: prefix || undefined }
}

export default Plugin.define({
  id: "pedropombeiro.forge-session",
  async setup(context) {
    const titles = context.client.rpc(ForgeSessionRpc)
    const location = context.location ?? context.data.location.default()
    const options = await resolveCliOptions(context.options, () => titles.options({}, { location }))
    // Without review status, the plugin keeps only the server's session
    // targets and titles, so this entry point adds nothing.
    if (!reviewStatusEnabled(options)) return

    const forges = new Forges(exec, hostsFrom(options))
    const pollSeconds = Number(options.pollSeconds) > 0 ? Number(options.pollSeconds) : 120
    // Running automated reviews poll faster so a finished review is noticed promptly.
    const reviewPollSeconds = Math.min(pollSeconds, 30)
    // `notifyDuoReview` is the option's former name.
    const notifyAutomatedReviews = (options.notifyAutomatedReviews ?? options.notifyDuoReview) !== false
    const notifyHumanReviews = options.notifyHumanReviews !== false
    // Shared across TUI instances, so only one of them notifies a session.
    const [notified, updateNotified] = context.storage.store("automatedReviewNotified", {
      initial: { sent: {} } as NotifiedLog,
    })
    // Per session and MR, the baseline and announced comments. Renaming the
    // store discards old records, which only makes MRs start a new baseline.
    const [feedbackLog, updateFeedbackLog] = context.storage.store("humanReviewFeedback.v3", {
      initial: { records: {} } as FeedbackLog,
    })

    // Reports a failure once per kind, so a persistent problem doesn't toast on every poll.
    const reported = new Set<string>()
    const reportOnce = (kind: string, prefix: string, error: unknown) => {
      if (reported.has(kind)) return
      reported.add(kind)
      const reason = error instanceof Error ? error.message : String(error)
      context.ui.toast.show({ message: `${prefix}: ${reason}`, variant: "error" })
    }

    // Reads the targets stored by set_session_target. Returns undefined when the
    // session has no explicit target or the RPC fails, for example while the
    // server entry point reloads. Title references and the branch still apply.
    async function rpcTargets(sessionID: string, directory: string) {
      try {
        return classifyTargets(await titles.target({ sessionID }, { location: { directory } }))
      } catch {
        return undefined
      }
    }

    const [version, setVersion] = createSignal(0)
    const store = createStatusStore({
      interval: pollSeconds * 1000,
      activeInterval: reviewPollSeconds * 1000,
      active: isReviewRunning,
      onChange: () => setVersion((value) => value + 1),
      onLoad: (key, _previous, next) => watch.onLoad(key, parseKey(key).sessionID, next),
      onLoadError: (error) => reportOnce("watch", "MR status watcher failed", error),
      async load(key): Promise<Lookup> {
        const { directory, sessionID, prefix } = parseKey(key)
        const targets = sessionID ? await rpcTargets(sessionID, directory) : undefined
        return locate(forges, { directory, targets, title: prefix, previous: store.get(key).lookup })
      },
    })

    // The displayed session can live in a different worktree than the one the
    // TUI started in, so resolve the directory from the session first.
    const directoryFor = (sessionID?: string) =>
      (sessionID ? context.data.session.get(sessionID)?.location.directory : undefined) ??
      context.location?.directory ??
      context.data.location.default().directory

    const keyFor = (sessionID?: string) =>
      keyOf({
        directory: directoryFor(sessionID),
        sessionID,
        prefix: sessionID ? titlePrefix(context.data.session.get(sessionID)?.title) : undefined,
      })

    const currentKey = () => {
      const route = context.ui.router.current()
      return keyFor(route.type === "session" ? route.sessionID : undefined)
    }

    const forDirectory = (directory: string, action: (key: string) => void) => {
      for (const key of store.keys()) if (parseKey(key).directory === directory) action(key)
    }

    // Storage writes run in the background; a failed write only risks a repeat.
    const persistLater = (write: () => unknown) => {
      void Promise.resolve().then(write).catch(() => {})
    }

    const automated = notifyAutomatedReviews
      ? createAutomatedReviewWatcher({
          // A recorded notification isn't retried, even if sending it fails.
          claim: createNotificationClaim({
            shared: () => notified,
            persist: (id, at) => persistLater(() => updateNotified((draft) => recordNotification(draft, id, at))),
          }),
          send: (sessionID, requests) => void notifyFinishedReviews(sessionID, requests),
        })
      : undefined

    const human = notifyHumanReviews
      ? createFeedbackWatcher({
          log: () => feedbackLog,
          persist: (key, change, at) =>
            persistLater(() => updateFeedbackLog((draft) => recordFeedback(draft, key, change, at))),
          async fetch(sessionID, request) {
            return traitsOf(request).feedback?.fetch(exec, directoryFor(sessionID), request)
          },
          current: (sessionID, mr) => watch.isTarget(sessionID, mr),
          send: sendFeedback,
          onFetchError: (error) => reportOnce("feedback-fetch", "Could not check MR review feedback", error),
          onSendError: (error) => {
            const reason = error instanceof Error ? error.message : String(error)
            context.ui.toast.show({ message: `Could not tell the session about review feedback: ${reason}`, variant: "error" })
          },
        })
      : undefined

    // Loads of an older key, such as one from before a title change, are
    // ignored. A session that isn't loaded can't be checked, so its key is trusted.
    const isCurrentKey = (key: string, sessionID: string) =>
      !context.data.session.get(sessionID) || keyFor(sessionID) === key

    // Keeps a session's target PR/MR polling while an automated review runs or
    // human feedback is watched, even when the session isn't on screen.
    const watch = createSessionWatch({
      acquire: (key) => store.acquire(key),
      isCurrent: isCurrentKey,
      automated,
      human,
    })

    async function sendFeedback(sessionID: string, mr: ReviewRequest, comments: ReviewComment[]) {
      await context.client.session.synthetic({
        sessionID,
        text: feedbackMessage(mr, comments),
        description: `New review feedback on ${reference(mr)}`,
        delivery: "queue",
        resume: true,
      })
      context.ui.toast.show({ ...feedbackToast(mr, comments), variant: "info" })
    }

    async function notifyFinishedReviews(sessionID: string, requests: ReviewRequest[]) {
      try {
        await context.client.session.synthetic({
          sessionID,
          text: reviewMessage(requests),
          description: reviewTitle(requests),
          delivery: "queue",
          resume: true,
        })
        context.ui.toast.show({ ...reviewToast(requests), variant: "info" })
      } catch (error) {
        const reason = error instanceof Error ? error.message : String(error)
        const name = automatedReview(requests[0])?.name ?? "the automated reviewer"
        context.ui.toast.show({ message: `Could not tell the session about ${name}'s review: ${reason}`, variant: "error" })
      }
    }

    const color = (tone: Tone) => {
      const feedback = context.theme.text.feedback
      if (tone === "success") return feedback.success.base
      if (tone === "warning") return feedback.warning.base
      if (tone === "error") return feedback.error.base
      return context.theme.text.muted
    }

    function Footer(props: { sessionID?: string }) {
      const key = createMemo(() => keyFor(props.sessionID))
      const directory = createMemo(() => parseKey(key()).directory)
      const branch = createMemo(() => context.data.location.vcs.info({ directory: directory() })?.branch.current)

      createEffect(() => onCleanup(store.acquire(key())))

      createEffect(() => {
        context.data.location.vcs.sync({ directory: directory() }).catch(() => {})
      })

      createEffect(
        on(
          [key, branch],
          ([current, currentBranch], previous) => {
            if (previous && previous[0] === current && previous[1] !== currentBranch) store.invalidate(current)
          },
          { defer: true },
        ),
      )

      const snapshot = createMemo(() => {
        version()
        return store.get(key())
      })
      const fullWidth = createMemo(() => segmentsWidth(footerSegments(snapshot())))
      const [availableWidth, setAvailableWidth] = createSignal(0)
      const segments = createMemo(() => responsiveFooterSegments(snapshot(), availableWidth()))

      return (
        <Show when={fullWidth() > 0}>
          <box
            flexDirection="row"
            width={fullWidth()}
            flexShrink={1}
            minWidth={0}
            height={1}
            overflow="hidden"
            onSizeChange={function (this: BoxRenderable) {
              const width = this.width
              queueMicrotask(() => setAvailableWidth(width))
            }}
          >
            <For each={segments()}>
              {(segment, index) => (
                <>
                  <Show when={index() > 0}>
                    <text wrapMode="none" flexShrink={0} fg={context.theme.text.muted}>
                      {" · "}
                    </text>
                  </Show>
                  <Show
                    when={segment.url}
                    fallback={
                      // Segments without a link of their own open the status dialog,
                      // which has the full detail behind the abbreviated indicator.
                      <text wrapMode="none" flexShrink={0} fg={color(segment.tone)} onMouseUp={() => showStatus(key())}>
                        {segment.text}
                      </text>
                    }
                  >
                    {(url: () => string) => (
                      // OSC 8 makes the text a terminal hyperlink where supported; the
                      // click handler covers terminals and multiplexers that drop it.
                      // The underline marks the segment as a link, because terminals
                      // don't style OSC 8 links consistently.
                      <text wrapMode="none" flexShrink={0} fg={color(segment.tone)} onMouseUp={() => openUrl(url())}>
                        <a href={url()}>
                          <u>{segment.text}</u>
                        </a>
                      </text>
                    )}
                  </Show>
                </>
              )}
            </For>
          </box>
        </Show>
      )
    }

    const openUrl = (url: string) => {
      const opener = process.platform === "darwin" ? "open" : "xdg-open"
      void exec(opener, [url], process.cwd()).then((result) => {
        if (result.code !== 0) context.ui.toast.show({ message: `Could not open ${url}`, variant: "error" })
      })
    }

    const requestsFor = (key: string): ReviewRequest[] => {
      const lookup = store.get(key).lookup
      return lookup?.kind === "found" ? lookup.requests : []
    }

    function StatusDialog(props: { statusKey: string }) {
      const [terminalHeight, setTerminalHeight] = createSignal(context.renderer.height)
      const onResize = () => setTerminalHeight(context.renderer.height)
      context.renderer.on("resize", onResize)
      onCleanup(() => context.renderer.off("resize", onResize))
      // Leave room for the dialog host, title, gaps, footer, and padding.
      // A maxHeight alone lets the scrollbox's content grow the dialog.
      const contentHeight = createMemo(() => Math.max(1, Math.min(24, Math.floor(terminalHeight() * 0.6) - 5)))
      const snapshot = createMemo(() => {
        version()
        return store.get(props.statusKey)
      })
      const refresh = () => {
        if (!snapshot().loading) void store.refresh(props.statusKey)
      }
      const [activeAction, setActiveAction] = createSignal<"refresh" | "close">("refresh")
      const moveAction = () =>
        setActiveAction((action) => (action === "refresh" || snapshot().loading ? "close" : "refresh"))
      const close = () => context.ui.dialog.clear()

      context.keymap.layer(() => ({
        mode: "modal",
        commands: [
          {
            id: "forge.review.status.refresh",
            bind: "ctrl+r",
            enabled: () => !snapshot().loading,
            run: refresh,
          },
          { bind: "tab", title: "Next dialog action", run: moveAction },
          { bind: "shift+tab", title: "Previous dialog action", run: moveAction },
          { bind: "left", title: "Previous dialog action", run: moveAction },
          { bind: "right", title: "Next dialog action", run: moveAction },
          {
            bind: "return",
            title: "Activate dialog action",
            run: () => {
              if (activeAction() === "refresh") refresh()
              else close()
            },
          },
        ],
      }))

      return (
        <box height={contentHeight() + 5} paddingLeft={2} paddingRight={2} paddingBottom={1} gap={1}>
          <box height={1} flexShrink={0} flexDirection="row" justifyContent="space-between">
            <text fg={context.theme.text.base}><b>PR/MR status</b></text>
            <text fg={context.theme.text.muted} onMouseUp={close}>esc</text>
          </box>
          <scrollbox
            height={contentHeight()}
            minHeight={1}
            flexShrink={0}
            scrollX={false}
            contentOptions={{ flexShrink: 0 }}
          >
            <text fg={context.theme.text.base}>{detailsMessage(snapshot())}</text>
          </scrollbox>
          <box height={1} flexShrink={0} flexDirection="row" justifyContent="flex-end">
            <For each={["close", "refresh"] as const}>
              {(action) => {
                const disabled = () => action === "refresh" && snapshot().loading
                const active = () => activeAction() === action && !disabled()
                return (
                  <box
                    paddingLeft={1}
                    paddingRight={1}
                    flexShrink={0}
                    backgroundColor={active() ? context.theme.background.action.primary.focused : undefined}
                    onMouseMove={() => {
                      if (!disabled()) setActiveAction(action)
                    }}
                    onMouseUp={() => {
                      if (disabled()) return
                      setActiveAction(action)
                      if (action === "refresh") refresh()
                      else close()
                    }}
                  >
                    <text
                      wrapMode="none"
                      fg={disabled()
                        ? context.theme.text.action.primary.disabled
                        : active() ? context.theme.text.action.primary.focused : context.theme.text.muted}
                    >
                      {action === "close" ? "Close" : snapshot().loading ? "Refreshing…" : "Refresh"}
                    </text>
                  </box>
                )
              }}
            </For>
          </box>
        </box>
      )
    }

    function showStatus(key = currentKey()) {
      void store.refresh(key)
      context.ui.dialog.set({ size: "large", centered: true })
      context.ui.dialog.show(() => <StatusDialog statusKey={key} />)
    }

    async function openRequest() {
      const key = currentKey()
      let requests = requestsFor(key)
      if (requests.length === 0) {
        await store.refresh(key)
        requests = requestsFor(key)
      }
      if (requests.length === 0) {
        context.ui.toast.show({ message: "No PR/MR for this session or branch", variant: "info" })
        return
      }
      if (requests.length === 1) return openUrl(requests[0].url)
      const url = await context.ui.dialog.select({
        title: "Open PR/MR",
        actions: [{ bind: "ctrl+w", title: "Close", side: "right", selection: "none", onTrigger: () => context.ui.dialog.clear() }],
        options: requests.map((mr) => ({ title: `${reference(mr)} ${mr.title}`, value: mr.url, description: mr.targetProject })),
      })
      if (url) openUrl(url)
    }

    context.ui.slot({
      append: "prompt.footer.status",
      render: (input) => <Footer sessionID={input.sessionID} />,
    })

    context.ui.slot({
      append: "app",
      render: () => {
        context.keymap.layer(() => ({
          mode: "global",
          commands: [
            {
              id: "forge.review.status",
              title: "Show PR/MR status",
              group: "Forge",
              palette: true,
              slash: { name: "forge-status", aliases: ["mr-status", "pr-status"] },
              run: () => showStatus(),
            },
            {
              id: "forge.review.open",
              title: "Open PR/MR in browser",
              group: "Forge",
              palette: true,
              slash: { name: "forge-open", aliases: ["mr-open", "pr-open"] },
              run: openRequest,
            },
          ],
        }))
        return null
      },
    })

    const notifySession = (sessionID: string, directory?: string) => {
      const dir = context.data.session.get(sessionID)?.location.directory ?? directory
      if (dir) forDirectory(dir, store.notify)
    }
    const stops = [
      context.data.on("session.execution.succeeded", (event) =>
        notifySession(event.data.sessionID, event.location?.directory),
      ),
      context.data.on("session.execution.failed", (event) =>
        notifySession(event.data.sessionID, event.location?.directory),
      ),
      context.data.on("vcs.branch.updated", (event) => {
        if (event.location) forDirectory(event.location.directory, store.invalidate)
      }),
      titles.events.on("targetChanged", (event) => {
        const { sessionID } = event.data as { sessionID: string }
        for (const key of store.keys()) if (parseKey(key).sessionID === sessionID) store.invalidate(key)
      }),
    ]

    return () => {
      for (const stop of stops) stop()
      watch.dispose()
      store.dispose()
    }
  },
})
