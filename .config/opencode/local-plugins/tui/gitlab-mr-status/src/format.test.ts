import { describe, expect, test } from "bun:test"
import { detailsMessage, footerSegments } from "./format"
import type { Repository } from "./git"
import type { MergeRequest } from "./gitlab"
import type { Snapshot } from "./store"

const repository: Repository = {
  head: "local",
  branch: "feature",
  sourceBranch: "feature",
  source: { host: "gitlab.com", path: "group/project" },
  targets: [],
}

const mr = (overrides: Partial<MergeRequest> = {}): MergeRequest => ({
  iid: "4281",
  title: "Add things",
  url: "https://gitlab.com/group/project/-/merge_requests/4281",
  state: "opened",
  draft: false,
  conflicts: false,
  approved: false,
  hasApprovals: false,
  approvalRequirementsSatisfied: false,
  targetProject: "group/project",
  targetBranch: "main",
  headSha: "local",
  pipeline: { status: "FAILED", label: "failed" },
  unresolvedThreads: 2,
  threadsComplete: true,
  ...overrides,
})

const snapshot = (mergeRequests: MergeRequest[], extra: Partial<Snapshot> = {}): Snapshot => ({
  lookup: { kind: "found", repository, mergeRequests },
  fetchedAt: 0,
  loading: false,
  ...extra,
})

const text = (value: Snapshot) => footerSegments(value).map((segment) => segment.text).join(" · ")

describe("footerSegments", () => {
  test("shows an active Duo review", () => {
    expect(text(snapshot([mr({ duoReviewState: "REVIEW_STARTED" })]))).toBe(
      "!4281 · CI failed · 2 unresolved threads · 🤖 reviewing",
    )
  })

  test.each(["REVIEWED", "UNREVIEWED", "APPROVED", undefined])("omits inactive Duo reviews: %s", (duoReviewState) => {
    expect(text(snapshot([mr({ duoReviewState })]))).not.toContain("🤖")
  })

  test("omits the Duo indicator on merged MRs", () => {
    expect(text(snapshot([mr({ state: "merged", duoReviewState: "REVIEW_STARTED" })]))).toBe("!4281 · merged")
  })
  test("shows the MR, pipeline, and threads", () => {
    expect(text(snapshot([mr()]))).toBe("!4281 · CI failed · 2 unresolved threads")
  })

  test("adds conflicts and approval, and omits resolved threads", () => {
    const value = snapshot([mr({ unresolvedThreads: 0, conflicts: true, approved: true, pipeline: undefined })])
    expect(text(value)).toBe("!4281 · no pipeline · conflicts · approved")
  })

  test("marks incomplete thread counts", () => {
    expect(text(snapshot([mr({ unresolvedThreads: 1, threadsComplete: false })]))).toContain("1+ unresolved threads")
  })

  test("is empty without an MR or repository", () => {
    expect(footerSegments(snapshot([]))).toEqual([])
    expect(footerSegments({ lookup: { kind: "none", reason: "Detached HEAD" }, loading: false })).toEqual([])
    expect(footerSegments({ loading: true })).toEqual([])
  })

  test("distinguishes a failed lookup from no MR", () => {
    const error = { kind: "auth" as const, message: "GitLab authentication failed", at: 0 }
    expect(text({ loading: false, error })).toBe("MR status unavailable")
    expect(text(snapshot([mr()], { error }))).toBe("!4281 · CI failed · 2 unresolved threads · stale")
  })

  test("does not pick one of several MRs", () => {
    expect(text(snapshot([mr(), mr({ iid: "9" })]))).toBe("!4281 · !9 · 2 open MRs, run /mr-status")
  })

  test("shows only the state of a merged or closed session target", () => {
    const merged = { lookup: { kind: "found" as const, sessionTarget: "!4281 (from the session title)", mergeRequests: [mr({ state: "merged" })] }, loading: false }
    expect(text(merged)).toBe("!4281 · merged")
    expect(detailsMessage(merged)).toContain("Session target: !4281")
  })

  test("links the MR and pipeline", () => {
    const [iid, pipeline, threads] = footerSegments(
      snapshot([mr({ pipeline: { status: "SUCCESS", label: "passed", url: "https://gitlab.com/p/-/pipelines/1" } })]),
    )
    expect(iid.url).toBe("https://gitlab.com/group/project/-/merge_requests/4281")
    expect(pipeline.url).toBe("https://gitlab.com/p/-/pipelines/1")
    expect(threads.url).toBeUndefined()
  })
})

describe("detailsMessage", () => {
  test("includes Duo's review state when available", () => {
    expect(detailsMessage(snapshot([mr({ duoReviewState: "REVIEW_STARTED" })]))).toContain("Duo review: review started")
    expect(detailsMessage(snapshot([mr({ duoReviewState: "REVIEWED" })]))).toContain("Duo review: reviewed")
    expect(detailsMessage(snapshot([mr()]))).not.toContain("Duo review:")
  })
  test("distinguishes actual approvals from satisfied requirements", () => {
    const message = detailsMessage(snapshot([mr({ approvalRequirementsSatisfied: true })]))
    expect(message).toContain("Has approvals: no · Approval requirements satisfied: yes")
  })

  test("reports unavailable approval requirements as unknown", () => {
    const message = detailsMessage(snapshot([mr({ approvalRequirementsSatisfied: null })]))
    expect(message).toContain("Approval requirements satisfied: unknown")
  })

  test("includes the URL and head mismatch", () => {
    const message = detailsMessage(snapshot([mr({ headSha: "remote" })]))
    expect(message).toContain("https://gitlab.com/group/project/-/merge_requests/4281")
    expect(message).toContain("Local HEAD differs")
  })

  test("explains why no lookup happened", () => {
    expect(detailsMessage({ lookup: { kind: "none", reason: "Detached HEAD" }, loading: false })).toContain(
      "Detached HEAD",
    )
  })
})
