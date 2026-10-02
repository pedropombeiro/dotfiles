// Per-command permission checks for tools called through lazy-mcp.
//
// OpenCode checks every lazy-mcp downstream call against the action
// `lazy-mcp_invoke_command` with resource `*`, so it cannot tell
// `gitlab/get_merge_request` from `gitlab/create_note`. This plugin records the
// downstream `server` and `command_name` in a `tool.execute.before` hook. Its
// `permission.evaluate` hook then re-evaluates the agent's permission rules for
// that action with the resource `server/command`, so opencode.json can hold rules
// such as:
//
//   { "action": "lazy-mcp_invoke_command", "resource": "gitlab/get_*", "effect": "allow" }
//
// - Matching follows OpenCode: `*` and `?` wildcards, and the last match wins.
//   A rule with resource `*` matches every downstream command.
// - An explicit `deny` that matches resource `*` is final and never reaches this hook.
// - Saved "Allow always" approvals are not part of the agent's rules, so they don't
//   bypass these checks. Per-command approvals belong in opencode.json.
//
// A hook that throws blocks every tool call, so the hooks never throw. When the
// plugin can't attribute or evaluate a check, it asks.

const WRAPPER = "lazy-mcp_invoke_command"
const MAX_PENDING = 256

const pending = new Map()
const key = (sessionID, messageID, id) => `${sessionID}:${messageID}:${id}`

const patterns = new Map()
const match = (value, pattern) => {
  let re = patterns.get(pattern)
  if (!re) {
    const source = pattern.replace(/[.+^${}()|[\]\\]/g, "\\$&").replaceAll("*", ".*").replaceAll("?", ".")
    re = new RegExp(`^${source}$`, "s")
    patterns.set(pattern, re)
  }
  return re.test(value)
}

const decide = (rules, resource) =>
  rules.findLast((rule) => match(WRAPPER, rule.action) && match(resource, rule.resource))?.effect

const unwrap = (response) => response?.data ?? response

// Returns the merged permission rules that apply to the session's agent,
// including project config for the session's directory.
const agentRules = async (ctx, event) => {
  const session = unwrap(await ctx.session.get({ sessionID: event.sessionID }))
  const agentID = event.agent ?? session?.agent
  if (!agentID) return undefined
  const location = session?.directory ? { directory: session.directory } : undefined
  return unwrap(await ctx.agent.get({ agentID, location }))?.permissions
}

const evaluate = async (ctx, event, call) => {
  if (!call) {
    event.effect = "ask"
    event.message = "lazy-mcp: could not identify the downstream command"
    return
  }
  const resource = `${call.server}/${call.command}`
  event.message = `lazy-mcp: ${resource}`
  try {
    const rules = await agentRules(ctx, event)
    const effect = Array.isArray(rules) ? decide(rules, resource) : undefined
    event.effect = effect ?? "ask"
  } catch (error) {
    event.effect = "ask"
    event.message = `lazy-mcp: ${resource} (could not read permission rules: ${error?.message ?? error})`
  }
}

export { decide, evaluate, key, match, pending, WRAPPER }

export default {
  id: "lazy-mcp-permissions",
  async setup(ctx) {
    await ctx.tool.hook("execute.before", (event) => {
      if (event.tool !== WRAPPER) return
      const input = event.input ?? {}
      // A rejected call never reaches execute.after, so drop the oldest entries.
      while (pending.size >= MAX_PENDING) pending.delete(pending.keys().next().value)
      pending.set(key(event.sessionID, event.messageID, event.id), {
        server: String(input.server ?? ""),
        command: String(input.command_name ?? ""),
      })
    })

    await ctx.tool.hook("execute.after", (event) => {
      if (event.tool === WRAPPER) pending.delete(key(event.sessionID, event.messageID, event.id))
    })

    await ctx.permission.hook("evaluate", async (event) => {
      if (event.action !== WRAPPER) return
      const source = event.source
      const call = source?.type === "tool" ? pending.get(key(event.sessionID, source.messageID, source.id)) : undefined
      await evaluate(ctx, event, call)
    })
  },
}
