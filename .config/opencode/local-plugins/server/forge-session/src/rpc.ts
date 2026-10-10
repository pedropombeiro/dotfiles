// Contract between the server, which stores each session's targets, and the
// CLI, which shows their status. The ID is the one that
// opencode-forge-session-title registered, so callers written for that
// package keep working.
const urls = {
  url: { type: "string" },
  issueUrl: { type: "string" },
} as const

// `url` and `issueUrl` describe the first target, for callers that expect a
// single target. `targets` lists every target in order.
const target = {
  type: "object",
  properties: {
    ...urls,
    targets: {
      type: "array",
      items: { type: "object", properties: urls, required: ["url"], additionalProperties: false },
    },
  },
  additionalProperties: false,
} as const

export const ForgeSessionRpc = {
  id: "opencode-forge-session-title",
  methods: {
    // The session's explicit targets, or `{}` in automatic branch mode.
    target: {
      input: {
        type: "object",
        properties: { sessionID: { type: "string" } },
        required: ["sessionID"],
        additionalProperties: false,
      },
      output: target,
    },
    // The CLI entry point's options, from the plugin's `opencode.json` entry.
    options: {
      input: { type: "object", additionalProperties: false },
      output: { type: "object" },
    },
  },
  events: {
    // Fires after set_session_target runs. Has only `sessionID` in branch mode.
    targetChanged: {
      schema: {
        type: "object",
        properties: { sessionID: { type: "string" }, ...target.properties },
        required: ["sessionID"],
        additionalProperties: false,
      },
    },
  },
} as const

export type TargetUrls = { url: string; issueUrl?: string }
export type TargetOutput = { url?: string; issueUrl?: string; targets?: TargetUrls[] }
