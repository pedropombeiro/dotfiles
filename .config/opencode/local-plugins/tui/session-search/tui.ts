import { Plugin } from "@opencode/plugin/tui"
import { execFile } from "node:child_process"
import { homedir } from "node:os"
import { join } from "node:path"
import {
  dialogTitle,
  noMatches,
  openSession,
  search,
  summarize,
  toOptions,
  type Exec,
  type Result,
  type Session,
} from "./src/search"

const SCRIPT = join(homedir(), ".agents", "skills", "session-search", "scripts", "search.py")
const TIMEOUT_MS = 120_000

function runScript(cwd: string | undefined): Exec {
  return (args, env) =>
    new Promise((resolve, reject) => {
      execFile(
        SCRIPT,
        args,
        { cwd, env: { ...process.env, ...env }, timeout: TIMEOUT_MS, maxBuffer: 16 * 1024 * 1024 },
        (error, stdout, stderr) => {
          if (error) reject(new Error(stderr.trim() || error.message))
          else resolve(stdout)
        },
      )
    })
}

export default Plugin.define({
  id: "pedropombeiro.session-search",
  setup(context) {
    const toast = context.ui.toast.show

    async function choose(query: string, result: Result) {
      const sessions = new Map<string, Session>(result.sessions.map((session) => [session.id, session]))
      const open = (id: string | undefined) => {
        const session = id ? sessions.get(id) : undefined
        if (!session) return
        const warning = openSession(context.ui, session)
        if (warning) toast(warning)
      }
      const id = await context.ui.dialog.select({
        title: dialogTitle(result),
        options: toOptions(result.sessions),
        actions: [
          {
            bind: "ctrl+s",
            title: "Summarize here",
            onTrigger: async (value: string) => {
              const session = sessions.get(value)
              if (!session) return
              context.ui.dialog.clear()
              toast(
                await summarize(query, session, context.ui.router.current(), (request) =>
                  context.client.session.prompt(request),
                ),
              )
            },
          },
        ],
      })
      open(id)
    }

    async function run(input?: string) {
      const query =
        input?.trim() ||
        (await context.ui.dialog.prompt({ title: "Search sessions", placeholder: "Keyword or sentence" }))?.trim()
      if (!query) return

      toast({ message: `Searching sessions for "${query}"…`, variant: "info" })
      let result: Result
      try {
        const location = context.location ?? context.data.location.default()
        result = await search(query, context.ui.router.current(), runScript(location?.directory))
      } catch (error) {
        const reason = error instanceof Error ? error.message : String(error)
        toast({ title: "Session search failed", message: reason, variant: "error" })
        return
      }
      if (result.sessions.length === 0) {
        toast({ message: noMatches(result), variant: "warning" })
        return
      }
      await choose(query, result)
    }

    return context.ui.slot({
      append: "app",
      render: () => {
        // Register during rendering so v2.0.22 can resolve Keymap.Provider.
        // The global mode keeps the command in the slash list; see
        // queue-command for details.
        context.keymap.layer(() => ({
          mode: "global",
          commands: [
            {
              id: "pedropombeiro.session-search",
              title: "Search sessions",
              group: "Session",
              bind: "<leader>f",
              palette: true,
              slash: { name: "search-session", arguments: true },
              run,
            },
          ],
        }))
        return null
      },
    })
  },
})
