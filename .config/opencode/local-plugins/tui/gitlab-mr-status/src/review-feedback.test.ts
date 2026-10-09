import { describe, expect, test } from "bun:test"
import type { GraphQL } from "./gitlab"
import { fetchFeedback, MAX_FEEDBACK_PAGES, toFeedbackNote } from "./review-feedback"

const node = (id: string, overrides: Record<string, unknown> = {}) => ({
  id: `gid://gitlab/DiscussionNote/${id}`,
  url: `https://gitlab.com/g/p/-/merge_requests/1#note_${id}`,
  createdAt: "2026-10-09T10:00:00Z",
  updatedAt: "2026-10-09T10:05:00Z",
  lastEditedAt: "2026-10-09T10:03:00Z",
  system: false,
  discussion: { resolved: false },
  author: { id: "gid://gitlab/User/2", username: "alice", bot: false },
  ...overrides,
})

// `previous` is the cursor for the page of older comments, if there is one.
const page = (nodes: unknown[], previous?: string, viewer: string | null = "gid://gitlab/User/1") => ({
  currentUser: viewer ? { id: viewer } : null,
  project: {
    mergeRequest: { notes: { pageInfo: { hasPreviousPage: !!previous, startCursor: previous ?? null }, nodes } },
  },
})

describe("toFeedbackNote", () => {
  test("uses the numeric ID and the last edit time", () => {
    expect(toFeedbackNote(node("5"))).toEqual({
      id: "5",
      url: "https://gitlab.com/g/p/-/merge_requests/1#note_5",
      editedAt: Date.parse("2026-10-09T10:03:00Z"),
      resolved: false,
      system: false,
      bot: false,
      authorID: "gid://gitlab/User/2",
      username: "alice",
    })
  })

  test("falls back to the update and creation times", () => {
    expect(toFeedbackNote(node("5", { lastEditedAt: null }))?.editedAt).toBe(Date.parse("2026-10-09T10:05:00Z"))
    expect(toFeedbackNote(node("5", { lastEditedAt: null, updatedAt: null }))?.editedAt).toBe(
      Date.parse("2026-10-09T10:00:00Z"),
    )
  })

  test("skips notes without an author or a valid time", () => {
    expect(toFeedbackNote(node("5", { author: null }))).toBeUndefined()
    expect(toFeedbackNote(node("5", { lastEditedAt: "nope" }))).toBeUndefined()
    expect(toFeedbackNote(node("5", { id: "gid://gitlab/Note/abc" }))).toBeUndefined()
  })

  test("reads the thread's resolution", () => {
    expect(toFeedbackNote(node("5", { discussion: { resolved: true } }))?.resolved).toBe(true)
  })
})

describe("fetchFeedback", () => {
  test("pages backwards from the newest comment and returns them oldest first", async () => {
    const calls: Record<string, string>[] = []
    const graphql: GraphQL = async (_host, _query, variables) => {
      calls.push(variables)
      return variables.before ? page([node("1"), node("2")]) : page([node("3"), node("4")], "c3")
    }
    const snapshot = await fetchFeedback(graphql, "gitlab.com", "g/p", "1")
    expect(snapshot?.complete).toBe(true)
    expect(snapshot?.viewerID).toBe("gid://gitlab/User/1")
    expect(snapshot?.notes.map((n) => n.id)).toEqual(["1", "2", "3", "4"])
    expect(calls).toEqual([
      { project: "g/p", iid: "1" },
      { project: "g/p", iid: "1", before: "c3" },
    ])
  })

  test("returns undefined for a missing MR", async () => {
    const graphql: GraphQL = async () => ({ currentUser: { id: "u" }, project: { mergeRequest: null } })
    expect(await fetchFeedback(graphql, "gitlab.com", "g/p", "1")).toBeUndefined()
  })

  test("stops at the newest comments and treats the full window as complete", async () => {
    let calls = 0
    // Each call returns an older page, with lower IDs.
    const graphql: GraphQL = async () => {
      calls++
      return page([node(String(1000 - calls))], `c${calls}`)
    }
    const snapshot = await fetchFeedback(graphql, "gitlab.com", "g/p", "1")
    expect(calls).toBe(MAX_FEEDBACK_PAGES)
    expect(snapshot?.complete).toBe(true)
    expect(snapshot?.notes.at(0)?.id).toBe(String(1000 - MAX_FEEDBACK_PAGES))
    expect(snapshot?.notes.at(-1)?.id).toBe("999")
  })

  test("marks a snapshot incomplete when an older page disappears", async () => {
    const graphql: GraphQL = async (_host, _query, variables) =>
      variables.before ? { project: null } : page([node("2")], "c2")
    expect((await fetchFeedback(graphql, "gitlab.com", "g/p", "1"))?.complete).toBe(false)
  })

  test("marks a snapshot incomplete when the older page has no cursor", async () => {
    const graphql: GraphQL = async () => ({
      currentUser: { id: "u" },
      project: { mergeRequest: { notes: { pageInfo: { hasPreviousPage: true, startCursor: null }, nodes: [] } } },
    })
    expect((await fetchFeedback(graphql, "gitlab.com", "g/p", "1"))?.complete).toBe(false)
  })

  test("marks a snapshot incomplete without the viewer's ID", async () => {
    const graphql: GraphQL = async () => page([node("1")], undefined, null)
    expect((await fetchFeedback(graphql, "gitlab.com", "g/p", "1"))?.complete).toBe(false)
  })
})
