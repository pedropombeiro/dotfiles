import { describe, expect, test } from "bun:test"
import { githubTraits } from "./github"
import { gitlabTraits } from "./gitlab"
import { classifyTarget } from "./target"

describe("classifyTarget", () => {
  test("recognizes a PR or MR target on any forge", () => {
    expect(classifyTarget({ url: "https://gitlab.com/group/project/-/merge_requests/42" })).toEqual({
      kind: "merge-request",
      ref: { forge: "gitlab", host: "gitlab.com", project: "group/project", iid: "42" },
    })
    expect(classifyTarget({ url: "https://github.com/owner/repo/pull/7" })).toEqual({
      kind: "merge-request",
      ref: { forge: "github", host: "github.com", project: "owner/repo", iid: "7" },
    })
  })

  test.each(["https://gitlab.com/group/project/-/issues/7", "https://github.com/owner/repo/issues/7"])(
    "marks an issue target as not a PR/MR: %s",
    (url) => {
      expect(classifyTarget({ url })).toEqual({ kind: "other", url })
    },
  )

  test("treats a missing target as automatic", () => {
    expect(classifyTarget({})).toBeUndefined()
    expect(classifyTarget({ url: 42 })).toBeUndefined()
    expect(classifyTarget(undefined)).toBeUndefined()
  })
})

describe("parseUrl", () => {
  test("parses a GitLab MR URL in a nested group", () => {
    expect(gitlabTraits.parseUrl("https://gitlab.com/gitlab-org/security/gitlab/-/merge_requests/42")).toEqual({
      forge: "gitlab",
      host: "gitlab.com",
      project: "gitlab-org/security/gitlab",
      iid: "42",
    })
  })

  test.each([
    "not a url",
    "https://gitlab.com/group/project/-/issues/42",
    "https://github.com/me/project/pull/42",
    "ftp://gitlab.com/group/project/-/merge_requests/42",
  ])("GitLab rejects %p", (value) => {
    expect(gitlabTraits.parseUrl(value)).toBeUndefined()
  })

  test.each([
    "https://github.com/owner/repo/issues/42",
    "https://github.com/owner/repo/pull/42/files",
    "https://gitlab.com/group/project/-/merge_requests/42",
    "https://github.com/owner/repo/pull/0",
  ])("GitHub rejects %p", (value) => {
    expect(githubTraits.parseUrl(value)).toBeUndefined()
  })
})
