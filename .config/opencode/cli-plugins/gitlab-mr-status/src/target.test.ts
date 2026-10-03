import { describe, expect, test } from "bun:test"
import { parseMergeRequestUrl } from "./target"

describe("parseMergeRequestUrl", () => {
  test("parses a GitLab MR URL", () => {
    expect(parseMergeRequestUrl("https://gitlab.com/gitlab-org/security/gitlab/-/merge_requests/42")).toEqual({
      host: "gitlab.com",
      project: "gitlab-org/security/gitlab",
      iid: "42",
    })
  })

  test.each([
    undefined,
    42,
    "not a url",
    "https://gitlab.com/group/project/-/issues/42",
    "https://github.com/me/project/pull/42",
    "ftp://gitlab.com/group/project/-/merge_requests/42",
  ])("rejects %p", (value) => {
    expect(parseMergeRequestUrl(value)).toBeUndefined()
  })
})
