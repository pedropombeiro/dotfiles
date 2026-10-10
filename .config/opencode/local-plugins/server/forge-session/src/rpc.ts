// Contract between the server, which stores each session's target, and the
// CLI, which shows the target's status. The ID is the one that
// opencode-forge-session-title registered, so callers written for that
// package keep working.
const target = {
  type: "object",
  properties: {
    url: { type: "string" },
    issueUrl: { type: "string" },
  },
  additionalProperties: false,
} as const

export const ForgeSessionRpc = {
  id: "opencode-forge-session-title",
  methods: {
    // `{ url, issueUrl? }` for an explicit target, `{}` in automatic branch mode.
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
    // Fires after set_session_target runs. Omits `url` for branch mode.
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

export type TargetOutput = { url?: string; issueUrl?: string }
