// Adds the `open_session` tool, which focuses another session of the current
// project in the terminal that shows the calling session. The tool runs in the
// background service, which has no access to the terminal UI, so it emits an
// RPC event that tui.tsx handles and acknowledges. opencode.json loads this
// directory through a path entry; OpenCode then loads tui.tsx in the CLI.
// The session-search skill and the /search-session command call this tool;
// update them if its name or behavior changes.
import type { Plugin } from "@opencode/plugin"
import { randomUUID } from "node:crypto"
import { rejectReason, type SessionRef } from "./src/match"
import { reply, waitForReply } from "./src/pending"
import { SessionOpenRpc, type OpenAction } from "./src/rpc"

const REPLY_TIMEOUT_MS = 3_000
const MAX_ANCESTORS = 10

type SessionGet = (input: { sessionID: string }) => Promise<SessionRef & { title?: string }>

async function ancestry(get: SessionGet, session: SessionRef): Promise<string[]> {
  const ids = [session.id]
  let parentID = session.parentID
  while (parentID && ids.length <= MAX_ANCESTORS) {
    ids.push(parentID)
    parentID = (await get({ sessionID: parentID })).parentID
  }
  return ids
}

function describe(action: OpenAction): string {
  return action === "tab" ? "focused its tab" : "navigated to it"
}

export default {
  id: "pedropombeiro.session-open",
  async setup(ctx) {
    const get = ctx.session.get as unknown as SessionGet
    const rpc = await ctx.rpc.register(SessionOpenRpc, {
      handled: async (input) => {
        const { requestID, action } = input as { requestID: string; action: OpenAction }
        reply(requestID, action)
        return {}
      },
    })

    const tools = await ctx.tool.transform((editor) => {
      editor.add({
        name: "open_session",
        description:
          "Open another OpenCode session of the current project in the user's terminal, focusing its tab or switching to it. " +
          "Optionally close the source tab after opening, preserving its conversation in history. " +
          "Only call it after the user chooses that action. It fails for sessions of other projects.",
        input: {
          type: "object",
          properties: {
            session_id: { type: "string", pattern: "^ses", description: "ID of the session to open." },
            close_source: {
              type: "boolean",
              description: "Close the source tab after opening the destination. Defaults to false. Does not delete history.",
            },
          },
          required: ["session_id"],
          additionalProperties: false,
        },
        execute: async (input, { sessionID, signal }) => {
          const { session_id: targetID, close_source: closeSource = false } = input as {
            session_id: string
            close_source?: boolean
          }
          const source = await get({ sessionID })
          let target: Awaited<ReturnType<SessionGet>>
          try {
            target = await get({ sessionID: targetID })
          } catch {
            throw new Error(`Session ${targetID} was not found.`)
          }
          const reason = rejectReason(source, target)
          if (reason) throw new Error(reason)

          const sourceSessionIDs = await ancestry(get, source)
          const targetSessionIDs = await ancestry(get, target)
          const requestID = randomUUID()
          const replied = waitForReply(requestID, REPLY_TIMEOUT_MS, signal)
          await rpc.events.emit("requested", {
            requestID,
            sourceSessionIDs,
            sessionID: target.id,
            rootSessionID: targetSessionIDs[targetSessionIDs.length - 1],
            root: !target.parentID,
            closeSource,
          })
          const action = await replied
          if (!action)
            throw new Error(
              `No terminal showing this session opened ${target.id}. Reopen it with \`opencode --session ${target.id}\`.`,
            )
          const title = target.title ? `"${target.title}" (${target.id})` : target.id
          return { content: `Opened ${title}: the terminal ${describe(action)}.` }
        },
      })
    })

    return async () => {
      await tools.dispose()
      await rpc.dispose()
    }
  },
} satisfies Plugin.Plugin
