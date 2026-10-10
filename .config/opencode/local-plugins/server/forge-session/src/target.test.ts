import { describe, expect, test } from "bun:test"
import { githubTraits } from "./github"
import { gitlabTraits } from "./gitlab"
import { classifyTarget, parseTarget, targetOutput, targetPrefix, targetRequest } from "./target"

describe("parseTarget", () => {
  test.each([
    ["https://gitlab.com/group/project/-/merge_requests/456", "[!456]"],
    ["https://gitlab.example.com/group/subgroup/project/-/merge_requests/456", "[!456]"],
    ["https://gitlab.com/group/project/-/issues/123", "[#123]"],
    ["https://gitlab.com/group/project/-/work_items/123", "[#123]"],
    ["https://github.com/owner/repo/pull/456", "[#456]"],
    ["https://github.com/owner/repo/issues/123", "[#123]"],
    ["https://github.example.com/owner/repo/pull/456", "[#456]"],
  ])("formats %s", (url, prefix) => {
    const target = parseTarget({ target: url })
    expect(target).toEqual({ url })
    expect(targetPrefix(target!)).toBe(prefix)
  })

  test("normalizes links and accepts an established related issue", () => {
    const target = parseTarget({
      target: "https://gitlab.com/group/project/-/merge_requests/456/?tab=changes#note_1",
      issue_url: "https://gitlab.com/group/other/-/issues/789",
    })
    expect(target?.url).toBe("https://gitlab.com/group/project/-/merge_requests/456")
    expect(targetPrefix(target!)).toBe("[#789, !456]")
  })

  test("supports returning to branch-based naming", () => {
    expect(parseTarget({ target: "branch" })).toBeUndefined()
  })

  test.each([
    {},
    { target: "!456" },
    { target: "file:///group/project/-/issues/123" },
    { target: "https://user:password@gitlab.com/group/project/-/issues/123" },
    { target: "https://github.com/owner/repo/pull/456/files" },
    { target: "https://gitlab.com/group/project/-/pipelines/7" },
    { target: "https://gitlab.com/group/project/issues/7" },
    { target: "branch", issue_url: "https://gitlab.com/group/project/-/issues/123" },
    {
      target: "https://gitlab.com/group/project/-/issues/123",
      issue_url: "https://gitlab.com/group/project/-/issues/789",
    },
    {
      target: "https://gitlab.com/group/project/-/merge_requests/456",
      issue_url: "https://gitlab.com/group/project/-/merge_requests/789",
    },
    {
      target: "https://gitlab.com/group/project/-/merge_requests/456",
      issue_url: "https://github.com/owner/repo/issues/1",
    },
  ])("rejects invalid input %j", (input) => {
    expect(() => parseTarget(input)).toThrow()
  })
})

describe("target requests and prefixes", () => {
  test("identifies pull and merge requests for source branch lookups", () => {
    expect(targetRequest({ url: "https://gitlab.example.com/group/sub/project/-/merge_requests/456" })).toEqual({
      forge: "gitlab",
      host: "gitlab.example.com",
      project: "group/sub/project",
      iid: "456",
    })
    expect(targetRequest({ url: "https://github.com/owner/repo/pull/7" })).toEqual({
      forge: "github",
      host: "github.com",
      project: "owner/repo",
      iid: "7",
    })
    expect(targetRequest({ url: "https://gitlab.com/group/project/-/issues/1" })).toBeUndefined()
  })

  test("uses a branch-derived issue unless an explicit issue is set", () => {
    const url = "https://gitlab.com/group/project/-/merge_requests/456"
    expect(targetPrefix({ url, branchIssue: "123" })).toBe("[#123, !456]")
    expect(targetPrefix({ url, branchIssue: "123", issueUrl: "https://gitlab.com/group/project/-/issues/9" })).toBe("[#9, !456]")
    expect(targetPrefix({ url: "https://gitlab.com/group/project/-/issues/5", branchIssue: "123" })).toBe("[#5]")
  })

  test("reports only the URLs over RPC", () => {
    expect(targetOutput(undefined)).toEqual({})
    expect(targetOutput({ url: "u", branchIssue: "1" })).toEqual({ url: "u" })
    expect(targetOutput({ url: "u", issueUrl: "i" })).toEqual({ url: "u", issueUrl: "i" })
  })
})

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
    "https://gitlab.example.com/owner/repo/pull/42",
  ])("GitHub rejects %p", (value) => {
    expect(githubTraits.parseUrl(value)).toBeUndefined()
  })
})

describe("parseIssueUrl", () => {
  test("parses issues and work items, but not PRs/MRs", () => {
    expect(gitlabTraits.parseIssueUrl("https://gitlab.com/g/sub/p/-/work_items/3")).toMatchObject({ project: "g/sub/p", iid: "3" })
    expect(gitlabTraits.parseIssueUrl("https://gitlab.com/g/p/-/merge_requests/3")).toBeUndefined()
    expect(githubTraits.parseIssueUrl("https://github.com/o/r/issues/3")).toMatchObject({ forge: "github", iid: "3" })
    expect(githubTraits.parseIssueUrl("https://github.com/o/r/pull/3")).toBeUndefined()
  })
})
