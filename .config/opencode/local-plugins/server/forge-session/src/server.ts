import type { Plugin } from "@opencode/plugin"
import type { TitleLookups } from "./lookups"
import { cliOptions } from "./options"
import { ForgeSessionRpc } from "./rpc"
import { parseTarget, targetOutput, targetPrefix, targetRequest, type Target } from "./target"
import { branchPrefix, extractIssueNumber, reconcileTitle } from "./title"

const SKIP_BRANCHES = new Set(["master", "main", "HEAD", "develop"])

// Stored per session. `prefix` is the title prefix this plugin last wrote, so
// it can be replaced without touching text the user added.
type SessionState = { target?: Target; prefix?: string }

const GUIDANCE = [
  "When the user establishes or changes the primary issue, PR, or MR for this session, call set_session_target with its full URL before starting that work.",
  "After you create a PR or MR for the current task (for example with gpsup, glab mr create, gh pr create, or a forge tool), call set_session_target with the new PR/MR URL. Pass the current issue as issue_url when the PR/MR was created for it.",
  "Background references, comparisons, and dependencies do not change the target. Follow-ups without a new primary target keep the current target.",
  "Include issue_url only when its relationship to the target PR/MR is established. Never carry over the checked-out branch’s issue to another target.",
  'When the user explicitly returns to work on the checked-out branch, call set_session_target with target "branch".',
]

// Stores each root session's target, keeps its title prefix current, and
// serves the target to the CLI over RPC.
export async function setupServer(ctx: Plugin.Context, lookups: TitleLookups) {
  const pending = new Map<string, Promise<void>>()
  const controller = new AbortController()

  async function stateFor(sessionID: string): Promise<SessionState> {
    return ((await ctx.storage.get(`sessions/${sessionID}`)) as SessionState | undefined) ?? {}
  }

  const rpc = await ctx.rpc.register(ForgeSessionRpc, {
    target: async (input) => {
      const { sessionID } = input as { sessionID: string }
      return targetOutput((await stateFor(sessionID)).target)
    },
    options: async () => cliOptions(ctx.options),
  })

  async function update(sessionID: string): Promise<void> {
    const session = await ctx.session.get({ sessionID })
    if (session.parentID || !session.title) return

    const directory = session.location.directory
    if (directory !== ctx.location.directory) return

    const state = await stateFor(sessionID)
    let prefix = state.target ? targetPrefix(state.target) : undefined
    if (!state.target) {
      const vcs = await ctx.vcs.get({ location: session.location })
      const info = vcs.data?.branch
      const branch = info?.current
      if (branch && !SKIP_BRANCHES.has(branch) && branch !== info?.default) {
        const found = await lookups.branch(directory)
        if (found) prefix = branchPrefix(found.forge, found.branch, found.number)
      }
    }

    const title = reconcileTitle(session.title, prefix, state.prefix)
    if (title !== session.title) await ctx.session.update({ sessionID, title })
    await ctx.storage.set(`sessions/${sessionID}`, {
      ...(state.target ? { target: state.target } : {}),
      ...(prefix ? { prefix } : {}),
    })
  }

  // Runs one update at a time per session, so a target change and a turn
  // ending at once can't interleave their reads and writes.
  function schedule(sessionID: string, action = () => update(sessionID)): Promise<void> {
    const previous = pending.get(sessionID) ?? Promise.resolve()
    const next = previous.then(action)
    const settled = next.catch(() => {})
    pending.set(sessionID, settled)
    void settled.then(() => {
      if (pending.get(sessionID) === settled) pending.delete(sessionID)
    })
    return next
  }

  const tools = await ctx.tool.transform((editor) => {
    editor.add({
      name: "set_session_target",
      description:
        'Set the primary issue, PR, or MR for this session title. Use a full URL, or "branch" to return to branch-based naming. Call it after creating a PR/MR for the current task. Without issue_url, the related issue is inferred from the PR/MR source branch name. This only changes local session metadata.',
      input: {
        type: "object",
        properties: {
          target: {
            type: "string",
            description: 'Full GitHub/GitLab issue, PR, or MR URL, or "branch".',
          },
          issue_url: {
            type: "string",
            description: "Optional full URL of an established related issue. Omit when unknown.",
          },
        },
        required: ["target"],
        additionalProperties: false,
      },
      execute: async (input, { sessionID }) => {
        const target = parseTarget(input)
        await schedule(sessionID, async () => {
          const session = await ctx.session.get({ sessionID })
          if (session.parentID || session.location.directory !== ctx.location.directory) {
            throw new Error("Session targets can only be set in the current root session.")
          }
          const request = target && !target.issueUrl ? targetRequest(target) : undefined
          const branch = request ? await lookups.sourceBranch(request, ctx.location.directory) : undefined
          const branchIssue = branch ? extractIssueNumber(branch) : undefined
          if (target && branchIssue) target.branchIssue = branchIssue
          const state = await stateFor(sessionID)
          await ctx.storage.set(`sessions/${sessionID}`, {
            ...(state.prefix ? { prefix: state.prefix } : {}),
            ...(target ? { target } : {}),
          })
          await rpc.events.emit("targetChanged", { sessionID, ...targetOutput(target) })
          await update(sessionID)
        })
        return { content: target ? `Session target: ${target.url}` : "Session target: checked-out branch." }
      },
    })
  })

  // A failure here must not block the model request, so it only skips the guidance.
  await ctx.session.hook("context", async (event) => {
    try {
      const session = await ctx.session.get({ sessionID: event.sessionID })
      if (session.parentID || session.location.directory !== ctx.location.directory) return
      const state = await stateFor(event.sessionID)
      event.system.push({
        type: "text",
        text: [
          ...GUIDANCE,
          `Current session target: ${state.target ? JSON.stringify(state.target) : "checked-out branch (automatic)"}.`,
        ].join("\n"),
      })
    } catch {}
  })

  void (async () => {
    for await (const event of ctx.event.subscribe({ signal: controller.signal })) {
      if (event.type === "session.renamed" || event.type === "session.execution.succeeded") {
        void schedule((event.data as { sessionID: string }).sessionID).catch(() => {})
      }
    }
  })().catch(() => {})

  return async () => {
    controller.abort()
    await tools.dispose()
    await rpc.dispose()
  }
}
