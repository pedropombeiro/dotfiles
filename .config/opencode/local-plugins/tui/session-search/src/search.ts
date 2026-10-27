// Runs the session-search skill script and turns its JSON into dialog options.
// The script stays the single implementation of the search; this module only
// builds its arguments and presents the result.

export type Match = { excerpt: string; source: string; time: string }

export type Session = {
  id: string
  title: string
  directory: string
  parent_id: string | null
  same_project: boolean | null
  archived: boolean
  last_match: string
  matches: Match[]
}

export type Search = { mode: "phrase" | "words"; include: string[]; total_sessions: number }

export type Result = {
  query: string
  mode: "phrase" | "words"
  include: string[]
  searches: Search[]
  total_sessions: number
  sessions: Session[]
}

// Runs the script with the given arguments and environment, resolving with
// its standard output. It rejects with the script's error message.
export type Exec = (args: string[], env: Record<string, string>) => Promise<string>

export type Option = { title: string; value: string; description: string; category: string }

export type Route = { type: string; sessionID?: string }

export const LIMIT = 30
const EXCERPT_LENGTH = 120

export function searchArgs(query: string): string[] {
  // `--` keeps a query that starts with a dash from being read as an option.
  return ["--format", "json", "--limit", String(LIMIT), "--excerpts", "1", "--", query]
}

// The script excludes $OPENCODE_SESSION_ID from the results and compares
// every session's project with it. Without a session, it falls back to the
// project of its working directory.
export async function search(query: string, route: Route, exec: Exec): Promise<Result> {
  const env: Record<string, string> = {}
  if (route.type === "session" && route.sessionID) env.OPENCODE_SESSION_ID = route.sessionID
  return JSON.parse(await exec(searchArgs(query), env)) as Result
}

export function clip(text: string, length = EXCERPT_LENGTH) {
  const line = text.replace(/\s+/g, " ").trim()
  return line.length > length ? `${line.slice(0, length - 1)}…` : line
}

export function describeSearch(search: Pick<Search, "mode" | "include">) {
  const parts = [search.mode === "words" ? "all words" : "exact phrase"]
  if (search.include.includes("tools")) parts.push("tool output")
  return parts.join(", ")
}

export function noMatches(result: Result) {
  const searches = result.searches.map(describeSearch).join("; ")
  return `No sessions matched "${clip(result.query, 40)}". Searched: ${searches}.`
}

export function dialogTitle(result: Result) {
  const count =
    result.total_sessions > result.sessions.length
      ? `${result.sessions.length} of ${result.total_sessions}`
      : String(result.sessions.length)
  const fallback = result.mode === "words" || result.include.includes("tools") ? `, ${describeSearch(result)}` : ""
  return `Sessions matching "${clip(result.query, 40)}" (${count}${fallback})`
}

// Sessions of the current project come first; the rest keep the script's
// newest-match-first order.
export function toOptions(sessions: Session[]): Option[] {
  const current = sessions.filter((session) => session.same_project === true)
  const other = sessions.filter((session) => session.same_project !== true)
  return [...current, ...other].map((session) => {
    const details = [session.last_match.slice(0, 10)]
    if (session.same_project !== true) details.push(session.directory)
    if (session.archived) details.push("archived")
    const excerpt = session.matches[0]?.excerpt
    if (excerpt) details.push(clip(excerpt))
    return {
      title: session.title || session.id,
      value: session.id,
      description: details.join(" · "),
      category: session.same_project === true ? "Current project" : "Other projects",
    }
  })
}

export interface SessionUI {
  router: { navigate(route: { type: "session"; sessionID: string }): void }
  tabs: { enabled(): boolean; focus(sessionID: string): void }
}

export type Toast = { title?: string; message: string; variant: "info" | "success" | "warning" | "error" }

// Matches the open_session tool: sessions of other projects stay closed,
// because the terminal shows the sessions of one project. Tabs hold root
// sessions only, so a child session opens through the router.
export function openSession(ui: SessionUI, session: Session): Toast | undefined {
  if (session.same_project !== true) {
    return {
      title: "Session belongs to another project",
      message: `Reopen it with: opencode --session ${session.id}`,
      variant: "warning",
    }
  }
  if (ui.tabs.enabled() && !session.parent_id) ui.tabs.focus(session.id)
  else ui.router.navigate({ type: "session", sessionID: session.id })
}

export type PromptRequest = { sessionID: string; text: string; delivery: "queue"; resume: true }

export function summaryPrompt(query: string, session: Session) {
  return [
    `Summarize what the previous session "${session.title}" (${session.id}) discussed about "${query}".`,
    "Load the `session-search` skill and run its script with",
    `\`--session ${session.id} --excerpts 10 --context 400\` to read the matches.`,
  ].join(" ")
}

// Queues the request like /queue does, so a busy session handles it after
// its current turn and an idle one starts right away.
export async function summarize(
  query: string,
  session: Session,
  route: Route,
  prompt: (request: PromptRequest) => Promise<unknown>,
): Promise<Toast> {
  if (route.type !== "session" || !route.sessionID) {
    return { message: "Open a session to summarize a search result in it", variant: "warning" }
  }
  try {
    await prompt({ sessionID: route.sessionID, text: summaryPrompt(query, session), delivery: "queue", resume: true })
    return { title: "Summary requested", message: clip(session.title, 60), variant: "success" }
  } catch (error) {
    const reason = error instanceof Error ? error.message : String(error)
    return { message: `Could not request the summary: ${reason}`, variant: "error" }
  }
}
