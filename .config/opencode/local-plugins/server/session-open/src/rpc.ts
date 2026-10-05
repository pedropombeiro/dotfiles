// Contract between the server tool and the CLI. The tool emits `requested`;
// the CLI that shows the requesting session opens the target and replies with
// `handled`, so the tool can report whether a terminal acted on it.
const requestSchema = {
  type: "object",
  properties: {
    requestID: { type: "string" },
    // The requesting session followed by its ancestors, so a request from a
    // subagent still reaches the terminal that shows the root session.
    sourceSessionIDs: { type: "array", items: { type: "string" } },
    sessionID: { type: "string" },
    root: { type: "boolean" },
  },
  required: ["requestID", "sourceSessionIDs", "sessionID", "root"],
  additionalProperties: false,
} as const

const handledSchema = {
  type: "object",
  properties: {
    requestID: { type: "string" },
    action: { type: "string", enum: ["tab", "route"] },
  },
  required: ["requestID", "action"],
  additionalProperties: false,
} as const

export const SessionOpenRpc = {
  id: "session-open",
  methods: {
    handled: { input: handledSchema, output: { type: "object", additionalProperties: false } },
  },
  events: {
    requested: { schema: requestSchema },
  },
} as const

export type OpenAction = "tab" | "route"

export interface OpenRequest {
  requestID: string
  sourceSessionIDs: string[]
  sessionID: string
  root: boolean
}
