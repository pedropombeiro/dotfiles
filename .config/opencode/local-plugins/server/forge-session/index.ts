// Merges opencode-forge-session-title and forge-review-status. This server
// entry point owns each session's target: the `set_session_target` tool, the
// agent guidance, the title prefix, and the RPC that serves the target.
// opencode.json loads this directory through a path entry; OpenCode then loads
// tui.tsx, which shows the target's PR/MR status, in the CLI.
//
// The ID is opencode-forge-session-title's, so stored targets carry over.
import type { Plugin } from "@opencode/plugin"
import { exec, execWithTimeout } from "./src/exec"
import { Forges, hostsFrom } from "./src/forges"
import { createTitleLookups } from "./src/lookups"
import { setupServer } from "./src/server"

export default {
  id: "opencode-forge-session-title",
  async setup(ctx) {
    const forges = new Forges(exec, hostsFrom((ctx.options ?? {}) as Record<string, unknown>))
    // set_session_target waits for the source branch lookup, so it gives up sooner.
    return setupServer(ctx, createTitleLookups(forges, execWithTimeout(15_000)))
  },
} satisfies Plugin.Plugin
