import { describe, expect, test } from "bun:test"
import type { GitHubPullRequest, GitLabMergeRequest } from "./forge"
import { createSessionWatch } from "./session-watch"
import type { Lookup } from "./store"

const mr = (overrides: Partial<GitLabMergeRequest> = {}): GitLabMergeRequest =>
  ({ forge: "gitlab", iid: "1", url: "https://gitlab.com/g/p/-/merge_requests/1", state: "opened", ...overrides }) as GitLabMergeRequest

const target = (overrides: Partial<GitLabMergeRequest> = {}): Lookup => ({
  kind: "found",
  explicitTarget: true,
  requests: [mr(overrides)],
})
const branch = (overrides: Partial<GitLabMergeRequest> = {}): Lookup => ({ kind: "found", requests: [mr(overrides)] })

function harness({ duo = true, human = true, current = (_key: string): boolean => true } = {}) {
  const counts = new Map<string, number>()
  const observed: Array<[Lookup | undefined, Lookup]> = []
  const checked: string[] = []
  const watch = createSessionWatch({
    acquire: (key) => {
      counts.set(key, (counts.get(key) ?? 0) + 1)
      return () => counts.set(key, counts.get(key)! - 1)
    },
    isCurrent: (key) => current(key),
    automated: duo ? { observe: (_sessionID, previous, next) => observed.push([previous, next]) } : undefined,
    human: human ? { check: (sessionID) => checked.push(sessionID) } : undefined,
  })
  const held = () => [...counts].filter(([, count]) => count > 0).map(([key]) => key)
  return { watch, observed, checked, held }
}

describe("createSessionWatch", () => {
  test("skips notifications when the target's forge lacks the capabilities", () => {
    const { watch, held, checked, observed } = harness()
    const pull = { forge: "github", iid: "1", url: "https://github.com/o/r/pull/1", state: "opened" } as GitHubPullRequest
    watch.onLoad("github", "ses_1", { kind: "found", explicitTarget: true, requests: [pull] })
    expect(held()).toEqual([])
    expect(checked).toEqual([])
    expect(observed).toEqual([])
  })
  test("holds an open explicit target for human feedback and checks it", () => {
    const { watch, held, checked } = harness({ duo: false })
    watch.onLoad("k1", "ses_1", target())
    expect(held()).toEqual(["k1"])
    expect(checked).toEqual(["ses_1"])
  })

  test("holds a reviewing target for Duo only while the review runs", () => {
    const { watch, held, observed } = harness({ human: false })
    watch.onLoad("k1", "ses_1", target())
    expect(held()).toEqual([])
    watch.onLoad("k1", "ses_1", target({ duoReviewState: "REVIEW_STARTED" }))
    expect(held()).toEqual(["k1"])
    watch.onLoad("k1", "ses_1", target({ duoReviewState: "REVIEWED" }))
    expect(held()).toEqual([])
    expect(observed.at(-1)).toEqual([target({ duoReviewState: "REVIEW_STARTED" }), target({ duoReviewState: "REVIEWED" })])
  })

  test("releases the hold and stops checking when the MR merges", () => {
    const { watch, held, checked } = harness({ duo: false })
    watch.onLoad("k1", "ses_1", target())
    watch.onLoad("k1", "ses_1", target({ state: "merged" }))
    expect(held()).toEqual([])
    expect(checked).toEqual(["ses_1"])
  })

  test("ignores MRs that aren't the session's explicit target", () => {
    const { watch, held, checked, observed } = harness()
    watch.onLoad("k1", "ses_1", branch({ duoReviewState: "REVIEW_STARTED" }))
    expect(held()).toEqual([])
    expect(checked).toEqual([])
    expect(observed).toEqual([])
  })

  test("releases the hold when the target is cleared", () => {
    const { watch, held } = harness()
    watch.onLoad("k1", "ses_1", target())
    watch.onLoad("k1", "ses_1", { kind: "none", reason: "Not an MR" })
    expect(held()).toEqual([])
  })

  test("ignores stale keys and releases their holds", () => {
    let currentKey = "k1"
    const { watch, held, checked } = harness({ current: (key) => key === currentKey })
    watch.onLoad("k1", "ses_1", target())
    currentKey = "k2"
    watch.onLoad("k1", "ses_1", target())
    expect(held()).toEqual([])
    expect(checked).toEqual(["ses_1"])
    watch.onLoad("k2", "ses_1", target())
    expect(held()).toEqual(["k2"])
  })

  test("keeps the previous lookup across a key change", () => {
    const { watch, observed } = harness()
    watch.onLoad("k1", "ses_1", target({ duoReviewState: "REVIEW_STARTED" }))
    watch.onLoad("k2", "ses_1", target({ duoReviewState: "REVIEWED" }))
    expect(observed.at(-1)?.[0]).toEqual(target({ duoReviewState: "REVIEW_STARTED" }))
  })

  test("reports whether an MR is still the session's target", () => {
    const { watch } = harness()
    watch.onLoad("k1", "ses_1", target())
    expect(watch.isTarget("ses_1", mr())).toBe(true)
    watch.onLoad("k1", "ses_1", target({ url: "https://gitlab.com/g/p/-/merge_requests/2" }))
    expect(watch.isTarget("ses_1", mr())).toBe(false)
    expect(watch.isTarget("ses_2", mr())).toBe(false)
  })

  test("ignores keys without a session and does nothing when both watchers are off", () => {
    const off = harness({ duo: false, human: false })
    off.watch.onLoad("k1", "ses_1", target({ duoReviewState: "REVIEW_STARTED" }))
    expect(off.held()).toEqual([])
    const { watch, held } = harness()
    watch.onLoad("k1", undefined, target())
    expect(held()).toEqual([])
  })

  test("releases every hold on dispose", () => {
    const { watch, held } = harness()
    watch.onLoad("k1", "ses_1", target())
    watch.onLoad("k2", "ses_2", target())
    watch.dispose()
    expect(held()).toEqual([])
  })
})
