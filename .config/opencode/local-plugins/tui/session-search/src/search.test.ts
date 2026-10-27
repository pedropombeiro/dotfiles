import { expect, test } from "bun:test"
import {
  clip,
  dialogTitle,
  noMatches,
  openSession,
  search,
  searchArgs,
  summarize,
  summaryPrompt,
  toOptions,
  type Result,
  type Session,
} from "./search"

function session(overrides: Partial<Session> = {}): Session {
  return {
    id: "ses_a",
    title: "Session A",
    directory: "/repo",
    parent_id: null,
    same_project: true,
    archived: false,
    last_match: "2026-10-09T19:33:47+02:00",
    matches: [{ excerpt: "…the palette entry…", source: "assistant", time: "2026-10-09T19:33:47+02:00" }],
    ...overrides,
  }
}

function result(overrides: Partial<Result> = {}): Result {
  return {
    query: "palette",
    mode: "phrase",
    include: [],
    searches: [{ mode: "phrase", include: [], total_sessions: 1 }],
    total_sessions: 1,
    sessions: [session()],
    ...overrides,
  }
}

test("passes the query after -- so a leading dash is not an option", () => {
  expect(searchArgs("--words")).toEqual(["--format", "json", "--limit", "30", "--excerpts", "1", "--", "--words"])
})

test("excludes the displayed session through OPENCODE_SESSION_ID", async () => {
  const calls: Array<Record<string, string>> = []
  const exec = async (_args: string[], env: Record<string, string>) => {
    calls.push(env)
    return JSON.stringify(result())
  }
  await search("q", { type: "session", sessionID: "ses_current" }, exec)
  await search("q", { type: "home" }, exec)
  expect(calls).toEqual([{ OPENCODE_SESSION_ID: "ses_current" }, {}])
})

test("lists current-project sessions first and describes the rest", () => {
  const options = toOptions([
    session({ id: "ses_other", title: "Other", same_project: false, directory: "/elsewhere", archived: true }),
    session({ id: "ses_mine", title: "", matches: [] }),
  ])
  expect(options).toEqual([
    { title: "ses_mine", value: "ses_mine", description: "2026-10-09", category: "Current project" },
    {
      title: "Other",
      value: "ses_other",
      description: "2026-10-09 · /elsewhere · archived · …the palette entry…",
      category: "Other projects",
    },
  ])
})

test("titles the dialog with the count and any fallback", () => {
  expect(dialogTitle(result())).toBe('Sessions matching "palette" (1)')
  expect(dialogTitle(result({ mode: "words", include: ["tools"], total_sessions: 40 }))).toBe(
    'Sessions matching "palette" (1 of 40, all words, tool output)',
  )
})

test("reports every search that ran when nothing matched", () => {
  const empty = result({
    query: "two words",
    sessions: [],
    total_sessions: 0,
    searches: [
      { mode: "phrase", include: [], total_sessions: 0 },
      { mode: "words", include: [], total_sessions: 0 },
      { mode: "words", include: ["tools"], total_sessions: 0 },
    ],
  })
  expect(noMatches(empty)).toBe(
    'No sessions matched "two words". Searched: exact phrase; all words; all words, tool output.',
  )
})

test("clip collapses whitespace and truncates", () => {
  expect(clip("a\n  b")).toBe("a b")
  expect(clip("x".repeat(20), 10)).toBe(`${"x".repeat(9)}…`)
})

function ui(tabs: boolean) {
  const calls: string[] = []
  return {
    calls,
    ui: {
      router: { navigate: (route: { sessionID: string }) => void calls.push(`navigate ${route.sessionID}`) },
      tabs: { enabled: () => tabs, focus: (id: string) => void calls.push(`focus ${id}`) },
    },
  }
}

test("focuses the tab of a root session and navigates to a child", () => {
  const { calls, ui: withTabs } = ui(true)
  expect(openSession(withTabs, session())).toBeUndefined()
  openSession(withTabs, session({ id: "ses_child", parent_id: "ses_a" }))
  const { calls: routed, ui: withoutTabs } = ui(false)
  openSession(withoutTabs, session())
  expect(calls).toEqual(["focus ses_a", "navigate ses_child"])
  expect(routed).toEqual(["navigate ses_a"])
})

test("does not open a session of another project", () => {
  const { calls, ui: withTabs } = ui(true)
  for (const same_project of [false, null]) {
    expect(openSession(withTabs, session({ same_project }))?.message).toBe("Reopen it with: opencode --session ses_a")
  }
  expect(calls).toHaveLength(0)
})

test("queues a summary request in the displayed session", async () => {
  const requests: unknown[] = []
  const toast = await summarize("palette", session(), { type: "session", sessionID: "ses_current" }, async (r) =>
    requests.push(r),
  )
  expect(requests).toEqual([
    { sessionID: "ses_current", text: summaryPrompt("palette", session()), delivery: "queue", resume: true },
  ])
  expect(toast.variant).toBe("success")
})

test("refuses to summarize outside a session and reports failures", async () => {
  const fail = async () => {
    throw new Error("boom")
  }
  expect((await summarize("q", session(), { type: "home" }, fail)).variant).toBe("warning")
  expect(await summarize("q", session(), { type: "session", sessionID: "ses_x" }, fail)).toEqual({
    message: "Could not request the summary: boom",
    variant: "error",
  })
})
