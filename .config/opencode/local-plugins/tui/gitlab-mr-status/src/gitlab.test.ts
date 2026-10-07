import { describe, expect, test } from "bun:test"
import type { Exec } from "./exec"
import type { Repository } from "./git"
import { footerSegments } from "./format"
import {
  classifyError,
  DISCUSSIONS_QUERY,
  findMergeRequestByIid,
  findMergeRequests,
  GitLabError,
  glabGraphQL,
  type GraphQL,
} from "./gitlab"

const repository: Repository = {
  head: "abc",
  branch: "feature",
  sourceBranch: "feature",
  source: { host: "gitlab.com", path: "me/project" },
  targets: [
    { host: "gitlab.com", path: "me/project" },
    { host: "gitlab.com", path: "group/project" },
  ],
}

const discussions = (nodes: Array<[boolean, boolean]>, endCursor: string | null = null) => ({
  pageInfo: { hasNextPage: endCursor !== null, endCursor },
  nodes: nodes.map(([resolvable, resolved]) => ({ resolvable, resolved })),
})

const node = (overrides: Record<string, unknown>) => ({
  iid: "1",
  title: "Title",
  webUrl: "https://gitlab.com/group/project/-/merge_requests/1",
  state: "OPENED",
  draft: false,
  conflicts: false,
  approved: false,
  approvedBy: { nodes: [] },
  detailedMergeStatus: "MERGEABLE",
  diffHeadSha: "abc",
  updatedAt: "2026-10-01T00:00:00Z",
  targetBranch: "main",
  sourceProject: { fullPath: "me/project" },
  targetProject: { fullPath: "group/project" },
  headPipeline: { status: "FAILED", path: "/group/project/-/pipelines/9", detailedStatus: { label: "failed" } },
  discussions: discussions([]),
  ...overrides,
})

describe("findMergeRequests", () => {
  test("counts unresolved threads across pages and filters other source projects", async () => {
    const calls: Array<Record<string, string>> = []
    const graphql: GraphQL = async (_host, query, variables) => {
      calls.push(variables)
      if (query === DISCUSSIONS_QUERY) {
        if (variables.after === "c1") return { project: { mergeRequest: { discussions: discussions([[true, false]], "c2") } } }
        return { project: { mergeRequest: { discussions: discussions([[true, false], [true, true]]) } } }
      }
      return {
        p0: { mergeRequests: { nodes: [] } },
        p1: {
          mergeRequests: {
            nodes: [
              node({
                discussions: discussions(
                  [
                    [true, false],
                    [false, false],
                    [true, true],
                  ],
                  "c1",
                ),
              }),
              node({ iid: "2", sourceProject: { fullPath: "someone-else/project" } }),
            ],
          },
        },
      }
    }

    const result = await findMergeRequests(graphql, repository)
    expect(calls[0]).toEqual({ branch: "feature", p0: "me/project", p1: "group/project" })
    expect(result).toHaveLength(1)
    expect(result[0]).toMatchObject({
      iid: "1",
      unresolvedThreads: 3,
      threadsComplete: true,
      pipeline: { status: "FAILED", label: "failed", url: "https://gitlab.com/group/project/-/pipelines/9" },
    })
  })

  test("returns an empty list without an MR and handles a missing pipeline", async () => {
    const empty: GraphQL = async () => ({ p0: { mergeRequests: { nodes: [] } }, p1: null })
    expect(await findMergeRequests(empty, repository)).toEqual([])

    const noPipeline: GraphQL = async () => ({ p0: { mergeRequests: { nodes: [node({ headPipeline: null, sourceProject: { fullPath: "Me/Project" } })] } } })
    const [mr] = await findMergeRequests(noPipeline, repository)
    expect(mr.pipeline).toBeUndefined()
  })

  test("lists several MRs from the same branch newest first", async () => {
    const graphql: GraphQL = async () => ({
      p0: { mergeRequests: { nodes: [node({ iid: "5", updatedAt: "2026-09-01T00:00:00Z" })] } },
      p1: { mergeRequests: { nodes: [node({ iid: "7", updatedAt: "2026-10-02T00:00:00Z" })] } },
    })
    expect((await findMergeRequests(graphql, repository)).map((mr) => mr.iid)).toEqual(["7", "5"])
  })
})

describe("findMergeRequestByIid", () => {
  const projects = [
    { host: "gitlab.com", path: "group/project" },
    { host: "gitlab.com", path: "security/project" },
  ]

  test.each(["REVIEW_STARTED", "REVIEWED", "UNREVIEWED", "APPROVED", null])(
    "reads Duo's review state: %s",
    async (reviewState) => {
      const graphql: GraphQL = async (_host, query) => {
        expect(query).toContain("type mergeRequestInteraction { reviewState }")
        return {
          p0: { mergeRequest: node({ reviewers: { nodes: [
            { type: "HUMAN", mergeRequestInteraction: { reviewState: "REVIEW_STARTED" } },
            { type: "DUO_CODE_REVIEW_BOT", mergeRequestInteraction: { reviewState } },
          ] } }) },
        }
      }
      const mr = await findMergeRequestByIid(graphql, projects, "1")
      expect(mr?.duoReviewState).toBe(reviewState ?? undefined)
    },
  )

  test("does not report human or unrelated bot reviews as Duo", async () => {
    const graphql: GraphQL = async () => ({
      p0: { mergeRequest: node({ reviewers: { nodes: [
        { type: "HUMAN", mergeRequestInteraction: { reviewState: "REVIEW_STARTED" } },
        { type: "PROJECT_BOT", mergeRequestInteraction: { reviewState: "REVIEW_STARTED" } },
      ] } }) },
    })
    expect((await findMergeRequestByIid(graphql, projects, "1"))?.duoReviewState).toBeUndefined()
  })

  test("handles a Duo reviewer with no interaction", async () => {
    const graphql: GraphQL = async () => ({
      p0: { mergeRequest: node({ reviewers: { nodes: [
        { type: "DUO_CODE_REVIEW_BOT", mergeRequestInteraction: null },
      ] } }) },
    })
    expect((await findMergeRequestByIid(graphql, projects, "1"))?.duoReviewState).toBeUndefined()
  })

  test.each([
    { requirements: true, approvers: [], approved: false },
    { requirements: true, approvers: [{ id: "gid://gitlab/User/1" }], approved: true },
    { requirements: false, approvers: [{ id: "gid://gitlab/User/1" }], approved: false },
    { requirements: null, approvers: [{ id: "gid://gitlab/User/1" }], approved: false },
  ])("requires actual approvals and satisfied requirements: %j", async ({ requirements, approvers, approved }) => {
    const graphql: GraphQL = async () => ({
      p0: { mergeRequest: node({ approved: requirements, approvedBy: { nodes: approvers } }) },
    })
    const mr = await findMergeRequestByIid(graphql, projects, "1")
    expect(mr).toMatchObject({
      approved,
      hasApprovals: approvers.length > 0,
      approvalRequirementsSatisfied: requirements,
    })
    const segments = footerSegments({ loading: false, lookup: { kind: "found", mergeRequests: [mr!] } })
    expect(segments.some((segment) => segment.text === "approved")).toBe(approved)
  })

  test("prefers the first project that has the MR", async () => {
    let seen: Record<string, string> = {}
    const graphql: GraphQL = async (_host, _query, variables) => {
      seen = variables
      return {
        p0: { mergeRequest: node({ iid: "42", state: "MERGED" }) },
        p1: { mergeRequest: node({ iid: "42", title: "Security fix" }) },
      }
    }
    const mr = await findMergeRequestByIid(graphql, projects, "42")
    expect(seen).toEqual({ iid: "42", p0: "group/project", p1: "security/project" })
    expect(mr).toMatchObject({ iid: "42", title: "Title", state: "merged" })
  })

  test("returns undefined when no project has the MR", async () => {
    const graphql: GraphQL = async () => ({ p0: { mergeRequest: null }, p1: null })
    expect(await findMergeRequestByIid(graphql, projects, "42")).toBeUndefined()
  })
})

describe("glabGraphQL", () => {
  const run =
    (stdout: string, stderr = "", code = 0): Exec =>
    async () => ({ stdout, stderr, code })

  test("passes variables as raw strings", async () => {
    let seen: string[] = []
    const exec: Exec = async (_file, args) => {
      seen = args
      return { stdout: '{"data":{"ok":true}}', stderr: "", code: 0 }
    }
    expect(await glabGraphQL(exec, "/repo")("gitlab.com", "query", { branch: "123" })).toEqual({ ok: true })
    expect(seen).toEqual(["api", "graphql", "--hostname", "gitlab.com", "-f", "query=query", "-f", "branch=123"])
  })

  test("classifies failures", async () => {
    const fail = (exec: Exec) => glabGraphQL(exec, "/repo")("gitlab.com", "q", {}).catch((error) => error)
    expect((await fail(run("", "glab: 401 Unauthorized", 1))).kind).toBe("auth")
    expect((await fail(run("", "spawn glab ENOENT", -1))).kind).toBe("missing-glab")
    expect((await fail(run("", "glab: 429 Too Many Requests", 1))).kind).toBe("rate-limit")
    const graphqlError = await fail(run('{"errors":[{"message":"Field missing"}]}', "", 1))
    expect(graphqlError).toBeInstanceOf(GitLabError)
    expect(graphqlError.message).toBe("Field missing")
  })

  test("classifyError keeps the first line of unknown errors", () => {
    expect(classifyError("glab: dial tcp: timeout\nmore", 1)).toMatchObject({ kind: "request", message: "dial tcp: timeout" })
  })
})
