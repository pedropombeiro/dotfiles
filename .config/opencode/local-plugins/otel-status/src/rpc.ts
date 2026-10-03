const emptySchema = { type: "object", additionalProperties: false } as const

const statusSchema = {
  type: "object",
  properties: {
    state: { type: "string", enum: ["checking", "reachable", "unreachable", "disabled"] },
    intervalMs: { type: "number" },
    protocol: { type: "string" },
    endpoint: { type: "string" },
    checkedAt: { type: "number" },
    latencyMs: { type: "number" },
    error: { type: "string" },
  },
  required: ["state", "intervalMs", "protocol"],
  additionalProperties: false,
} as const

export const OtelStatusRpc = {
  id: "otel-status",
  methods: {
    status: { input: emptySchema, output: statusSchema },
    check: { input: emptySchema, output: statusSchema },
  },
  events: {
    changed: { schema: statusSchema },
  },
} as const
