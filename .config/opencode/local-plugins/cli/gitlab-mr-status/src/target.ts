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

export interface MergeRequestRef {
  host: string
  project: string
  iid: string
}

export type SessionTarget = { kind: "merge-request"; ref: MergeRequestRef } | { kind: "other"; url: string }

// Classifies the `target` RPC output. Undefined means the session has no
// explicit target; "other" is an explicit target that isn't an MR, such as an issue.
export function classifyTarget(output: unknown): SessionTarget | undefined {
  const url = (output as { url?: unknown } | undefined)?.url
  if (typeof url !== "string" || !url) return undefined
  const ref = parseMergeRequestUrl(url)
  return ref ? { kind: "merge-request", ref } : { kind: "other", url }
}

export function parseMergeRequestUrl(value: unknown): MergeRequestRef | undefined {
  if (typeof value !== "string") return undefined
  let url: URL
  try {
    url = new URL(value)
  } catch {
    return undefined
  }
  if (!["https:", "http:"].includes(url.protocol)) return undefined
  const match = url.pathname.match(/^\/(.+)\/-\/merge_requests\/([1-9]\d*)\/?$/)
  if (!match) return undefined
  return { host: url.hostname.toLowerCase(), project: decodeURIComponent(match[1]), iid: match[2] }
}
