import { describe, expect, test } from "bun:test"
import {
  automatedReview,
  createAutomatedReviewWatcher,
  createNotificationClaim,
  finishedReviews,
  isReviewRunning,
  NOTIFY_WINDOW,
  notificationKey,
  recentlyNotified,
  recordNotification,
  reviewMessage,
  reviewOutcome,
  reviewTitle,
  reviewToast,
  type NotifiedLog,
} from "./automated-review-watch"
import type { GitHubPullRequest, GitLabMergeRequest, ReviewRequest } from "./forge"
import type { Lookup } from "./store"

const mr = (duoReviewState?: string, iid = "4281"): GitLabMergeRequest =>
  ({ forge: "gitlab", iid, url: `https://gitlab.com/group/project/-/merge_requests/${iid}`, duoReviewState }) as GitLabMergeRequest

const found = (...requests: ReviewRequest[]): Lookup => ({ kind: "found", explicitTarget: true, requests })

describe("isReviewRunning", () => {
  test("detects a running review", () => {
    expect(isReviewRunning(found(mr("REVIEWED"), mr("REVIEW_STARTED", "2")))).toBe(true)
  })

  test.each([["REVIEWED"], ["APPROVED"], [undefined]])("ignores %s", (state) => {
    expect(isReviewRunning(found(mr(state)))).toBe(false)
  })

  test("handles missing lookups", () => {
    expect(isReviewRunning(undefined)).toBe(false)
    expect(isReviewRunning({ kind: "none", reason: "Detached HEAD" })).toBe(false)
  })
})

describe("finishedReviews", () => {
  test.each(["REVIEWED", "REQUESTED_CHANGES"])("reports a review that finished as %s", (state) => {
    expect(finishedReviews(found(mr("REVIEW_STARTED")), found(mr(state)))).toEqual([mr(state)])
  })

  test.each(["APPROVED", "UNREVIEWED", "UNAPPROVED", "REVIEW_STARTED", undefined])(
    "ignores a review that ended as %s",
    (state) => {
      expect(finishedReviews(found(mr("REVIEW_STARTED")), found(mr(state)))).toEqual([])
    },
  )

  test("ignores a review that was already finished on the first load", () => {
    expect(finishedReviews(undefined, found(mr("REVIEWED")))).toEqual([])
    expect(finishedReviews(found(mr("REVIEWED")), found(mr("REVIEWED")))).toEqual([])
  })

  test("matches MRs by URL", () => {
    expect(finishedReviews(found(mr("REVIEW_STARTED", "1")), found(mr("REVIEWED", "2")))).toEqual([])
  })
})

describe("reviewMessage", () => {
  test("names the reviewer, the MR, and its final state", () => {
    const message = reviewMessage([mr("REQUESTED_CHANGES")])
    expect(message).toStartWith("GitLab Duo finished reviewing !4281")
    expect(message).toContain("GitLab Duo's new comments and discussion threads on the MR")
    expect(reviewTitle([mr("REVIEWED")])).toBe("GitLab Duo finished reviewing !4281")
    expect(message).toContain("!4281 (https://gitlab.com/group/project/-/merge_requests/4281)")
    expect(message).toContain('"requested changes"')
  })

  test("lists every review that finished together, with its URL and state", () => {
    const requests = [mr("REVIEWED", "1"), mr("REQUESTED_CHANGES", "2")]
    expect(reviewTitle(requests)).toBe("GitLab Duo finished reviewing 2 MRs")
    expect(reviewMessage(requests)).toBe(
      [
        "GitLab Duo finished reviewing 2 MRs:",
        '- !1 (https://gitlab.com/group/project/-/merge_requests/1) with the state "reviewed"',
        '- !2 (https://gitlab.com/group/project/-/merge_requests/2) with the state "requested changes"',
        "For each one, fetch the reviewer's new comments and discussion threads, then work through its feedback.",
      ].join("\n"),
    )
    expect(reviewToast(requests)).toEqual({
      title: "GitLab Duo finished reviewing 2 MRs",
      message: "!1: reviewed, !2: requested changes. Sent to the agent.",
    })
    expect(reviewToast([mr("REVIEWED")]).message).toBe("Reviewed. Sent to the agent.")
  })
})

describe("reviewOutcome", () => {
  test.each([
    ["REVIEWED", "Reviewed"],
    ["REQUESTED_CHANGES", "Requested changes"],
  ])("formats %s", (state, outcome) => {
    expect(reviewOutcome(mr(state))).toBe(outcome)
  })
})

describe("notification log", () => {
  test("suppresses repeats within the window", () => {
    const log: NotifiedLog = { sent: {} }
    const key = notificationKey("ses_1", mr("REVIEWED"))
    expect(recentlyNotified(log, key, 1_000)).toBe(false)
    recordNotification(log, key, 1_000)
    expect(recentlyNotified(log, key, 1_000 + NOTIFY_WINDOW - 1)).toBe(true)
    expect(recentlyNotified(log, key, 1_000 + NOTIFY_WINDOW)).toBe(false)
    expect(recentlyNotified(log, notificationKey("ses_2", mr("REVIEWED")), 1_000)).toBe(false)
  })

  test("prunes old entries", () => {
    const log: NotifiedLog = { sent: { old: 0 } }
    recordNotification(log, "new", 2 * 24 * 60 * 60_000)
    expect(Object.keys(log.sent)).toEqual(["new"])
  })
})

describe("createNotificationClaim", () => {
  test("claims a key once, even before the shared log catches up", () => {
    const persisted: string[] = []
    const claim = createNotificationClaim({
      shared: () => ({ sent: {} }),
      persist: (key) => persisted.push(key),
      now: () => 1_000,
    })
    expect(claim("a")).toBe(true)
    expect(claim("a")).toBe(false)
    expect(claim("b")).toBe(true)
    expect(persisted).toEqual(["a", "b"])
  })

  test("respects claims recorded by other TUI instances", () => {
    const persisted: string[] = []
    const claim = createNotificationClaim({
      shared: () => ({ sent: { a: 900 } }),
      persist: (key) => persisted.push(key),
      now: () => 1_000,
    })
    expect(claim("a")).toBe(false)
    expect(persisted).toEqual([])
  })
})

describe("createAutomatedReviewWatcher", () => {
  test("notifies once per claimed finished review", () => {
    const sent: Array<[string, string[]]> = []
    const claimed: string[] = []
    const watcher = createAutomatedReviewWatcher({
      claim: (key) => (claimed.push(key), claimed.length === 1),
      send: (sessionID, requests) => sent.push([sessionID, requests.map((request) => automatedReview(request)?.label ?? "")]),
    })
    watcher.observe("ses_1", found(mr("REVIEW_STARTED")), found(mr("REQUESTED_CHANGES")))
    watcher.observe("ses_1", found(mr("REVIEW_STARTED")), found(mr("REQUESTED_CHANGES")))
    expect(claimed).toEqual([notificationKey("ses_1", mr()), notificationKey("ses_1", mr())])
    expect(sent).toEqual([["ses_1", ["requested changes"]]])
  })

  test("sends reviews of several targets that finished in one poll together", () => {
    const sent: string[][] = []
    const watcher = createAutomatedReviewWatcher({
      claim: (key) => !key.endsWith("/3"),
      send: (_sessionID, requests) => sent.push(requests.map((request) => request.iid)),
    })
    const before = found(mr("REVIEW_STARTED", "1"), mr("REVIEW_STARTED", "2"), mr("REVIEW_STARTED", "3"), mr("REVIEW_STARTED", "4"))
    const after = found(mr("REVIEWED", "1"), mr("REVIEW_STARTED", "2"), mr("REVIEWED", "3"), mr("REQUESTED_CHANGES", "4"))
    watcher.observe("ses_1", before, after)
    // !2 is still running, and another CLI already claimed !3.
    expect(sent).toEqual([["1", "4"]])
    watcher.observe("ses_1", after, found(mr("REVIEWED", "1"), mr("REVIEWED", "2")))
    expect(sent).toEqual([["1", "4"], ["2"]])
  })

  test("ignores approvals and running reviews", () => {
    const sent: string[] = []
    const watcher = createAutomatedReviewWatcher({ claim: () => true, send: (sessionID) => sent.push(sessionID) })
    watcher.observe("ses_1", found(mr("REVIEW_STARTED")), found(mr("APPROVED")))
    watcher.observe("ses_1", undefined, found(mr("REVIEW_STARTED")))
    expect(sent).toEqual([])
  })
})

describe("automated review capability", () => {
  test("maps GitLab Duo states", () => {
    expect(automatedReview(mr("REVIEW_STARTED"))).toEqual({ name: "GitLab Duo", state: "running", label: "review started" })
    expect(automatedReview(mr("REQUESTED_CHANGES"))?.state).toBe("feedback")
    expect(automatedReview(mr("APPROVED"))?.state).toBe("settled")
    expect(automatedReview(mr())).toBeUndefined()
  })

  test("ignores forges without the capability", () => {
    const pull = { forge: "github", iid: "1", url: "https://github.com/o/r/pull/1" } as GitHubPullRequest
    expect(automatedReview(pull)).toBeUndefined()
    expect(isReviewRunning(found(pull))).toBe(false)
    expect(finishedReviews(found(pull), found(pull))).toEqual([])
  })
})
