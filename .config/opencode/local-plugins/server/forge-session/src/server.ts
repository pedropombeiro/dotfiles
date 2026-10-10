import type { Plugin } from "@opencode/plugin"
import { CONCURRENCY, mapLimit } from "./limit"
import type { TitleLookups } from "./lookups"
import { cliOptions } from "./options"
import { ForgeSessionRpc } from "./rpc"
import {
  applyTargetChange,
  MAX_TARGETS,
  parseTargetChange,
  targetOutput,
  targetRequest,
  targetsPrefix,
  type Target,
} from "./target"
import { branchPrefix, extractIssueNumber, reconcileTitle } from "./title"

const SKIP_BRANCHES = new Set(["master", "main", "HEAD", "develop"])

// Stored per session. `prefix` is the title prefix this plugin last wrote, so
// it can be replaced without touching text the user added. Before sessions
// could have several targets, the state held a single `target`.
type StoredState = { target?: Target; targets?: Target[]; prefix?: string }
type SessionState = { targets: Target[]; prefix?: string }

const GUIDANCE = [
  "When the user establishes or changes the primary issue, PR, or MR for this session, call set_session_target with its full URL before starting that work.",
  "When the user asks you to work on several issues, PRs, or MRs together, call set_session_target with all of their full URLs in targets. If the user describes them instead of linking them, find them first, then set them before starting that work.",
  'After you create a PR or MR for the current task (for example with gpsup, glab mr create, gh pr create, or a forge tool), call set_session_target with the new PR/MR URL. Pass the current issue as issue_url when the PR/MR was created for it. If the session has several targets that are still part of the task, use operation "add" so they are kept.',
  'When the user drops some of several targets from the task, call set_session_target with operation "remove" and their URLs.',
  "Background references, comparisons, and dependencies do not change the target. Follow-ups without a new primary target keep the current target.",
  "Include issue_url only when its relationship to the target PR/MR is established. Never carry over the checked-out branch’s issue to another target.",
  'When the user explicitly returns to work on the checked-out branch, call set_session_target with target "branch".',
]

function describeTargets(targets: readonly Target[]): string {
  if (targets.length === 0) return "checked-out branch (automatic)"
  if (targets.length === 1) return JSON.stringify(targets[0])
  return `${targets.length} targets: ${JSON.stringify(targets)}`
}

function toolResult(targets: readonly Target[], missing: readonly string[]): string {
  const lines =
    targets.length === 0
      ? ["Session target: checked-out branch."]
      : targets.length === 1
        ? [`Session target: ${targets[0].url}`]
        : [`Session targets (${targets.length}):`, ...targets.map((target) => `- ${target.url}`)]
  if (missing.length) lines.push(`Not session targets, so not removed: ${missing.join(", ")}`)
  return lines.join("\n")
}

// Stores each root session's targets, keeps its title prefix current, and
// serves the targets to the CLI over RPC.
export async function setupServer(ctx: Plugin.Context, lookups: TitleLookups) {
  const pending = new Map<string, Promise<void>>()
  const controller = new AbortController()

  async function stateFor(sessionID: string): Promise<SessionState> {
    const stored = ((await ctx.storage.get(`sessions/${sessionID}`)) as StoredState | undefined) ?? {}
    const targets = Array.isArray(stored.targets) ? stored.targets : stored.target ? [stored.target] : []
    return { targets, ...(stored.prefix ? { prefix: stored.prefix } : {}) }
  }

  const save = (sessionID: string, state: SessionState) =>
    ctx.storage.set(`sessions/${sessionID}`, {
      ...(state.targets.length ? { targets: state.targets } : {}),
      ...(state.prefix ? { prefix: state.prefix } : {}),
    })

  const rpc = await ctx.rpc.register(ForgeSessionRpc, {
    target: async (input) => {
      const { sessionID } = input as { sessionID: string }
      return targetOutput((await stateFor(sessionID)).targets)
    },
    options: async () => cliOptions(ctx.options),
  })

  async function update(sessionID: string): Promise<void> {
    const session = await ctx.session.get({ sessionID })
    if (session.parentID || !session.title) return

    const directory = session.location.directory
    if (directory !== ctx.location.directory) return

    const state = await stateFor(sessionID)
    let prefix = targetsPrefix(state.targets)
    if (state.targets.length === 0) {
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
    await save(sessionID, { targets: state.targets, ...(prefix ? { prefix } : {}) })
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

  // Infers the related issue of each PR/MR target from its source branch.
  // Targets the session already had were looked up when they were added.
  async function inferIssues(targets: Target[], previous: readonly Target[]) {
    const known = new Set(previous.filter((target) => !target.issueUrl).map((target) => target.url))
    await mapLimit(targets, CONCURRENCY, async (target) => {
      if (target.issueUrl || target.branchIssue || known.has(target.url)) return
      const request = targetRequest(target)
      const branch = request ? await lookups.sourceBranch(request, ctx.location.directory) : undefined
      const issue = branch ? extractIssueNumber(branch) : undefined
      if (issue) target.branchIssue = issue
    })
  }

  const tools = await ctx.tool.transform((editor) => {
    editor.add({
      name: "set_session_target",
      description:
        'Set the issues, PRs, or MRs this session works on, for its title and PR/MR status. Use target for one full URL, or "branch" to return to branch-based naming. Use targets for several full URLs. The default operation, "replace", sets exactly the given targets; "add" keeps the current targets, and "remove" drops the given ones. Call it after creating a PR/MR for the current task. Without issue_url, the related issue is inferred from the PR/MR source branch name. This only changes local session metadata.',
      input: {
        type: "object",
        properties: {
          target: {
            type: "string",
            description: 'Full GitHub/GitLab issue, PR, or MR URL, or "branch".',
          },
          targets: {
            type: "array",
            items: { type: "string" },
            minItems: 1,
            maxItems: MAX_TARGETS,
            description: "Several full GitHub/GitLab issue, PR, or MR URLs, instead of target.",
          },
          operation: {
            type: "string",
            enum: ["replace", "add", "remove"],
            description: 'How the given targets change the current ones. Defaults to "replace".',
          },
          issue_url: {
            type: "string",
            description: "Optional full URL of an established related issue for a single target. Omit when unknown.",
          },
        },
        additionalProperties: false,
      },
      execute: async (input, { sessionID }) => {
        const change = parseTargetChange(input)
        let result: { targets: Target[]; missing: string[] } = { targets: [], missing: [] }
        await schedule(sessionID, async () => {
          const session = await ctx.session.get({ sessionID })
          if (session.parentID || session.location.directory !== ctx.location.directory) {
            throw new Error("Session targets can only be set in the current root session.")
          }
          const state = await stateFor(sessionID)
          result = applyTargetChange(state.targets, change)
          await inferIssues(result.targets, state.targets)
          await save(sessionID, { targets: result.targets, ...(state.prefix ? { prefix: state.prefix } : {}) })
          await rpc.events.emit("targetChanged", { sessionID, ...targetOutput(result.targets) })
          await update(sessionID)
        })
        return { content: toolResult(result.targets, result.missing) }
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
        text: [...GUIDANCE, `Current session target: ${describeTargets(state.targets)}.`].join("\n"),
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
