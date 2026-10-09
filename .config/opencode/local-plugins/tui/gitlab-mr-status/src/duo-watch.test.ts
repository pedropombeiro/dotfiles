import { describe, expect, test } from "bun:test"
import {
  duoReviewMessage,
  duoReviewOutcome,
  finishedDuoReviews,
  isDuoReviewing,
  NOTIFY_WINDOW,
  notificationKey,
  recentlyNotified,
  recordNotification,
  type NotifiedLog,
} from "./duo-watch"
import type { MergeRequest } from "./gitlab"
import type { Lookup } from "./store"

const mr = (duoReviewState?: string, iid = "4281"): MergeRequest =>
  ({ iid, url: `https://gitlab.com/group/project/-/merge_requests/${iid}`, duoReviewState }) as MergeRequest

const found = (...mergeRequests: MergeRequest[]): Lookup => ({ kind: "found", explicitTarget: true, mergeRequests })

describe("isDuoReviewing", () => {
  test("detects a running review", () => {
    expect(isDuoReviewing(found(mr("REVIEWED"), mr("REVIEW_STARTED", "2")))).toBe(true)
  })

  test.each([["REVIEWED"], ["APPROVED"], [undefined]])("ignores %s", (state) => {
    expect(isDuoReviewing(found(mr(state)))).toBe(false)
  })

  test("handles missing lookups", () => {
    expect(isDuoReviewing(undefined)).toBe(false)
    expect(isDuoReviewing({ kind: "none", reason: "Detached HEAD" })).toBe(false)
  })
})

describe("finishedDuoReviews", () => {
  test.each(["REVIEWED", "REQUESTED_CHANGES"])("reports a review that finished as %s", (state) => {
    expect(finishedDuoReviews(found(mr("REVIEW_STARTED")), found(mr(state)))).toEqual([mr(state)])
  })

  test.each(["APPROVED", "UNREVIEWED", "UNAPPROVED", "REVIEW_STARTED", undefined])(
    "ignores a review that ended as %s",
    (state) => {
      expect(finishedDuoReviews(found(mr("REVIEW_STARTED")), found(mr(state)))).toEqual([])
    },
  )

  test("ignores a review that was already finished on the first load", () => {
    expect(finishedDuoReviews(undefined, found(mr("REVIEWED")))).toEqual([])
    expect(finishedDuoReviews(found(mr("REVIEWED")), found(mr("REVIEWED")))).toEqual([])
  })

  test("matches MRs by URL", () => {
    expect(finishedDuoReviews(found(mr("REVIEW_STARTED", "1")), found(mr("REVIEWED", "2")))).toEqual([])
  })
})

describe("duoReviewMessage", () => {
  test("names the MR and its final state", () => {
    const message = duoReviewMessage(mr("REQUESTED_CHANGES"))
    expect(message).toContain("!4281 (https://gitlab.com/group/project/-/merge_requests/4281)")
    expect(message).toContain('"requested changes"')
  })
})

describe("duoReviewOutcome", () => {
  test.each([
    ["REVIEWED", "Reviewed"],
    ["REQUESTED_CHANGES", "Requested changes"],
  ])("formats %s", (state, outcome) => {
    expect(duoReviewOutcome(mr(state))).toBe(outcome)
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
