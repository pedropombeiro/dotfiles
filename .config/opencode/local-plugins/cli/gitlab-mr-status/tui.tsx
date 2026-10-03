/** @jsxImportSource @opentui/solid */
// OpenCode resolves a local plugin directory's CLI entry point as `<dir>/tui`,
// so this file stays at the directory root. It is loaded only through the
// path entry in cli.base.json##class.Work; the parent directory is outside
// OpenCode's plugin discovery paths.
import { Plugin } from "@opencode/plugin/tui"
import { createEffect, createMemo, createSignal, For, on, onCleanup, Show } from "solid-js"
import { exec } from "./src/exec"
import { detailsMessage, footerSegments, type Tone } from "./src/format"
import { resolveProjects, resolveRepository, titleMergeRequest } from "./src/git"
import { findMergeRequestByIid, findMergeRequests, glabGraphQL, type MergeRequest } from "./src/gitlab"
import { createStatusStore, type Lookup } from "./src/store"
import { ForgeSessionTitleRpc, parseMergeRequestUrl } from "./src/target"

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
    const forge = context.client.rpc(ForgeSessionTitleRpc)

    // Reads the target stored by set_session_target. Returns undefined when the
    // session has no explicit target or the server lacks the RPC, for example
    // with an opencode-forge-session-title release that predates it.
    async function rpcTarget(sessionID: string, directory: string) {
      try {
        const output = (await forge.target({ sessionID }, { location: { directory } })) as { url?: unknown }
        return parseMergeRequestUrl(output?.url)
      } catch {
        return undefined
      }
    }

    const [version, setVersion] = createSignal(0)
    const store = createStatusStore({
      interval: pollSeconds * 1000,
      onChange: () => setVersion((value) => value + 1),
      async load(key): Promise<Lookup> {
        const { directory, sessionID, titleIid } = parseKey(key)
        const graphql = glabGraphQL(exec, directory)

        // Prefer the exact MR from set_session_target, then the MR number in the
        // session title, and finally the checked-out branch's open MR.
        const target = sessionID ? await rpcTarget(sessionID, directory) : undefined
        if (target) {
          const project = { host: target.host, path: target.project }
          const mr = await findMergeRequestByIid(graphql, [project], target.iid)
          if (mr) return { kind: "found", sessionTarget: mr.url, mergeRequests: [mr] }
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

      const segments = createMemo(() => {
        version()
        return footerSegments(store.get(key()))
      })

      return (
        <Show when={segments().length > 0}>
          <box flexDirection="row" flexShrink={0}>
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
                      <text wrapMode="none" flexShrink={0} fg={color(segment.tone)} onMouseUp={() => openUrl(url())}>
                        <a href={url()}>{segment.text}</a>
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

    async function showStatus() {
      const snapshot = await store.refresh(currentKey())
      const closed = context.ui.dialog.alert({ title: "Merge request status", message: detailsMessage(snapshot) })
      context.ui.dialog.set({ size: "large" })
      await closed
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
      store.dispose()
    }
  },
})
