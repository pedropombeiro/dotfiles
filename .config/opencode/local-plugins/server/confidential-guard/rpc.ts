const input = (properties: Record<string, { type: "string" }>) =>
  ({
    type: "object",
    properties,
    required: Object.keys(properties),
    additionalProperties: false,
  }) as const;

const session = { sessionID: { type: "string" } } as const;
const finding = { ...session, findingID: { type: "string" } } as const;

export const ConfidentialGuardRpc = {
  id: "confidential-guard",
  methods: {
    status: { input: input(session), output: { type: "object" } },
    recheck: { input: input(finding), output: { type: "object" } },
    dismissPromptFinding: { input: input(finding), output: { type: "object" } },
  },
  events: {},
} as const;

export default ConfidentialGuardRpc;
