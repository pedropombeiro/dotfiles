import type { ReviewRef } from "./forge"
import { parseUrl } from "./forges"

// The RPC that opencode-forge-session-title registers on the server. A local
// plugin can't import it from the package, so the definition is copied from
// that package's README.
export const ForgeSessionTitleRpc = {
  id: "opencode-forge-session-title",
  methods: {
    target: {
      input: {
        type: "object",
        properties: { sessionID: { type: "string" } },
        required: ["sessionID"],
      },
      output: {
        type: "object",
        properties: { url: { type: "string" }, issueUrl: { type: "string" } },
      },
    },
  },
  events: {
    targetChanged: {
      schema: {
        type: "object",
        properties: {
          sessionID: { type: "string" },
          url: { type: "string" },
          issueUrl: { type: "string" },
        },
        required: ["sessionID"],
      },
    },
  },
} as const

export type SessionTarget = { kind: "merge-request"; ref: ReviewRef } | { kind: "other"; url: string }

// Classifies the `target` RPC output. Undefined means the session has no
// explicit target; "other" is an explicit target that isn't a PR/MR, such as an issue.
export function classifyTarget(output: unknown): SessionTarget | undefined {
  const url = (output as { url?: unknown } | undefined)?.url
  if (typeof url !== "string" || !url) return undefined
  const ref = parseUrl(url)
  return ref ? { kind: "merge-request", ref } : { kind: "other", url }
}
