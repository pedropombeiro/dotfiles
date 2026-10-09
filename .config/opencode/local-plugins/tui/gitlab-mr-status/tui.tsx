/** @jsxImportSource @opentui/solid */
// OpenCode resolves a local plugin directory's CLI entry point as `<dir>/tui`,
// so this file stays at the directory root. It is loaded only through the
// path entry in cli.base.json##class.Work; the parent directory is outside
// OpenCode's plugin discovery paths.
import { Plugin } from "@opencode/plugin/tui"
import type { BoxRenderable } from "@opentui/core"
import { createEffect, createMemo, createSignal, For, on, onCleanup, Show } from "solid-js"
import {
  duoReviewMessage,
  duoReviewOutcome,
  finishedDuoReviews,
  isDuoReviewing,
  notificationKey,
  recentlyNotified,
  recordNotification,
  type NotifiedLog,
} from "./src/duo-watch"
import { exec } from "./src/exec"
import { detailsMessage, footerSegments, responsiveFooterSegments, segmentsWidth, type Tone } from "./src/format"
import { resolveProjects, resolveRepository, titleMergeRequest } from "./src/git"
import { findMergeRequestByIid, findMergeRequests, glabGraphQL, type MergeRequest } from "./src/gitlab"
import { createStatusStore, type Lookup } from "./src/store"
import { classifyTarget, ForgeSessionTitleRpc } from "./src/target"

// Cache keys are per session, because sessions sharing a checkout can target
// different MRs. The title's MR number is part of the key so a title change
// triggers a new lookup.
interface Key {
  directory: string
  sessionID?: string
  titleIid?: string
}
const keyOf = (key: Key) => JSON.stringify([key.directory, key.sessionID ?? "", key.titleIid ?? ""])
const parseKey = (key: string): Key => {
  const [directory, sessionID, titleIid] = JSON.parse(key) as [string, string, string]
  return { directory, sessionID: sessionID || undefined, titleIid: titleIid || undefined }
}

export default Plugin.define({
  id: "pedropombeiro.gitlab-mr-status",
  setup(context) {
    const hosts: string[] = Array.isArray(context.options.hosts) ? context.options.hosts : ["gitlab.com"]
    const pollSeconds = Number(context.options.pollSeconds) > 0 ? Number(context.options.pollSeconds) : 120
    // Duo reviews poll faster so a finished review is noticed promptly.
    const reviewPollSeconds = Math.min(pollSeconds, 30)
    const notifyDuoReview = context.options.notifyDuoReview !== false
    const forge = context.client.rpc(ForgeSessionTitleRpc)
    // Shared across TUI instances, so only one of them notifies a session.
    const [notified, updateNotified] = context.storage.store("duoReviewNotified", {
      initial: { sent: {} } as NotifiedLog,
    })

    // Reads the target stored by set_session_target. Returns undefined when the
    // session has no explicit target or the server lacks the RPC, for example
    // with an opencode-forge-session-title release that predates it.
    async function rpcTarget(sessionID: string, directory: string) {
      try {
        return classifyTarget(await forge.target({ sessionID }, { location: { directory } }))
      } catch {
        return undefined
      }
    }

    const [version, setVersion] = createSignal(0)
    const store = createStatusStore({
      interval: pollSeconds * 1000,
      activeInterval: reviewPollSeconds * 1000,
      active: isDuoReviewing,
      onChange: () => setVersion((value) => value + 1),
      onLoad: (key, previous, next) => watchDuoReview(key, previous, next),
      async load(key): Promise<Lookup> {
        const { directory, sessionID, titleIid } = parseKey(key)
        const graphql = glabGraphQL(exec, directory)

        // Prefer the exact MR from set_session_target, then the MR number in the
        // session title, and finally the checked-out branch's open MR.
        const target = sessionID ? await rpcTarget(sessionID, directory) : undefined
        // An explicit target that isn't an MR, such as an issue, means the
        // session isn't about an MR, so the branch's MR would be misleading.
        if (target?.kind === "other") {
          return { kind: "none", reason: `The session target is not a merge request (${target.url})` }
        }
        if (target) {
          const project = { host: target.ref.host, path: target.ref.project }
          const mr = await findMergeRequestByIid(graphql, [project], target.ref.iid)
          if (mr) return { kind: "found", sessionTarget: mr.url, explicitTarget: true, mergeRequests: [mr] }
        }
        if (titleIid && !target) {
          const projects = await resolveProjects(exec, directory, hosts)
          if (projects.kind === "projects") {
            const mr = await findMergeRequestByIid(graphql, projects.projects, titleIid)
            if (mr) return { kind: "found", sessionTarget: `!${titleIid} (from the session title)`, mergeRequests: [mr] }
          }
        }

        const lookup = await resolveRepository(exec, directory, hosts)
        if (lookup.kind === "none") return lookup
        const mergeRequests = await findMergeRequests(graphql, lookup.repository)
        return { kind: "found", repository: lookup.repository, mergeRequests }
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
        titleIid: sessionID ? titleMergeRequest(context.data.session.get(sessionID)?.title) : undefined,
      })

    const currentKey = () => {
      const route = context.ui.router.current()
      return keyFor(route.type === "session" ? route.sessionID : undefined)
    }

    const forDirectory = (directory: string, action: (key: string) => void) => {
      for (const key of store.keys()) if (parseKey(key).directory === directory) action(key)
    }

    // Keeps a session's lookup polling while Duo reviews its target MR, even
    // when the session isn't on screen.
    const reviewHolds = new Map<string, () => void>()

    function watchDuoReview(key: string, previous: Lookup | undefined, next: Lookup) {
      const { sessionID } = parseKey(key)
      const explicit = next.kind === "found" && next.explicitTarget === true
      if (!notifyDuoReview || !sessionID || !explicit) {
        reviewHolds.get(key)?.()
        reviewHolds.delete(key)
        return
      }

      if (isDuoReviewing(next)) {
        if (!reviewHolds.has(key)) reviewHolds.set(key, store.acquire(key))
      } else {
        reviewHolds.get(key)?.()
        reviewHolds.delete(key)
      }

      for (const mr of finishedDuoReviews(previous, next)) void notifyFinishedReview(sessionID, mr)
    }

    async function notifyFinishedReview(sessionID: string, mr: MergeRequest) {
      const notificationID = notificationKey(sessionID, mr)
      const now = Date.now()
      if (recentlyNotified(notified, notificationID, now)) return
      // Record before sending so a concurrent TUI skips it; a failed send isn't retried.
      await updateNotified((draft) => recordNotification(draft, notificationID, now))
      try {
        await context.client.session.synthetic({
          sessionID,
          text: duoReviewMessage(mr),
          description: `Duo finished reviewing !${mr.iid}`,
          delivery: "queue",
          resume: true,
        })
        context.ui.toast.show({
          title: `Duo finished reviewing !${mr.iid}`,
          message: `${duoReviewOutcome(mr)}. Sent to the agent.`,
          variant: "info",
        })
      } catch (error) {
        const reason = error instanceof Error ? error.message : String(error)
        context.ui.toast.show({ message: `Could not tell the session about Duo's review: ${reason}`, variant: "error" })
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
                      <text wrapMode="none" flexShrink={0} fg={color(segment.tone)}>
                        {segment.text}
                      </text>
                    }
                  >
                    {(url) => (
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

    const mergeRequestsFor = (key: string): MergeRequest[] => {
      const lookup = store.get(key).lookup
      return lookup?.kind === "found" ? lookup.mergeRequests : []
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
            id: "gitlab.mr.status.refresh",
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
            <text fg={context.theme.text.base}><b>Merge request status</b></text>
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

    function showStatus() {
      const key = currentKey()
      void store.refresh(key)
      context.ui.dialog.set({ size: "large", centered: true })
      context.ui.dialog.show(() => <StatusDialog statusKey={key} />)
    }

    async function openMergeRequest() {
      const key = currentKey()
      let requests = mergeRequestsFor(key)
      if (requests.length === 0) {
        await store.refresh(key)
        requests = mergeRequestsFor(key)
      }
      if (requests.length === 0) {
        context.ui.toast.show({ message: "No merge request for this session or branch", variant: "info" })
        return
      }
      if (requests.length === 1) return openUrl(requests[0].url)
      const url = await context.ui.dialog.select({
        title: "Open merge request",
        options: requests.map((mr) => ({ title: `!${mr.iid} ${mr.title}`, value: mr.url, description: mr.targetProject })),
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
              id: "gitlab.mr.status",
              title: "Show merge request status",
              group: "GitLab",
              palette: true,
              slash: { name: "mr-status" },
              run: showStatus,
            },
            {
              id: "gitlab.mr.open",
              title: "Open merge request in browser",
              group: "GitLab",
              palette: true,
              slash: { name: "mr-open" },
              run: openMergeRequest,
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
      forge.events.on("targetChanged", (event) => {
        const { sessionID } = event.data as { sessionID: string }
        for (const key of store.keys()) if (parseKey(key).sessionID === sessionID) store.invalidate(key)
      }),
    ]

    return () => {
      for (const stop of stops) stop()
      for (const release of reviewHolds.values()) release()
      reviewHolds.clear()
      store.dispose()
    }
  },
})
