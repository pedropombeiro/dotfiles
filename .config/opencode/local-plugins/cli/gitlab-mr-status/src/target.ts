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
