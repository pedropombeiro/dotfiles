import { describe, expect, test } from "bun:test"
import type { Forge, ForgeKind, GitHubPullRequest, GitLabMergeRequest, ReviewRequest } from "./forge"
import { kinds, traits, type ForgeCatalog } from "./forges"
import type { RemoteProject, Repository, RepositoryLookup } from "./git"
import { locate } from "./locate"
import { classifyTarget } from "./target"

// Finds `found` by its own number only, like a forge that has just that PR/MR.
class FakeForge implements Forge {
  readonly calls: string[] = []
  readonly traits

  constructor(
    kind: ForgeKind,
    private readonly found?: ReviewRequest,
    private readonly branch: ReviewRequest[] = [],
  ) {
    this.traits = traits(kind)
  }

  async findByNumber(projects: readonly RemoteProject[], number: string) {
    this.calls.push(`number ${projects.map((project) => project.path).join(",")} ${number}`)
    return this.found?.iid === number ? this.found : undefined
  }

  async findByBranch(repository: Repository) {
    this.calls.push(`branch ${repository.sourceBranch}`)
    return this.branch
  }
}

const merge = { forge: "gitlab", iid: "45", url: "https://gitlab.com/g/p/-/merge_requests/45" } as GitLabMergeRequest
const pull = { forge: "github", iid: "7", url: "https://github.com/o/r/pull/7" } as GitHubPullRequest
const repository = (host: string): RepositoryLookup => ({
  kind: "repository",
  repository: { head: "abc", branch: "feature", sourceBranch: "feature", source: { host, path: "o/r" }, targets: [] },
})
const onGitLab = { gitlab: [{ host: "gitlab.com", path: "g/p" }] }
const onGitHub = { github: [{ host: "github.com", path: "o/r" }] }

function catalog(
  forges: Partial<Record<ForgeKind, FakeForge>>,
  extra: { projects?: Partial<Record<ForgeKind, RemoteProject[]>>; repository?: RepositoryLookup } = {},
): ForgeCatalog {
  const kind = (host: string): ForgeKind | undefined =>
    host === "github.com" ? "github" : host.includes("gitlab") ? "gitlab" : undefined
  return {
    kinds,
    kind,
    forHost: (host) => {
      const match = kind(host)
      return match ? forges[match] : undefined
    },
    projects: async (_directory, match) => extra.projects?.[match] ?? [],
    repository: async () => extra.repository ?? { kind: "none", reason: "Not a Git repository" },
  }
}

const target = (url: string) => classifyTarget({ url })

describe("locate", () => {
  test("resolves explicit targets with the matching forge and skips titles and the branch", async () => {
    const gitlab = new FakeForge("gitlab", merge)
    const github = new FakeForge("github", pull)
    const forges = catalog({ gitlab, github }, { projects: onGitLab, repository: repository("gitlab.com") })
    expect(await locate(forges, { directory: "/repo", target: target(merge.url) })).toEqual({
      kind: "found", sessionTarget: merge.url, explicitTarget: true, requests: [merge],
    })
    expect(await locate(forges, { directory: "/repo", target: target(pull.url), title: "[!45]" })).toMatchObject({
      explicitTarget: true, requests: [pull],
    })
    expect(gitlab.calls).toEqual(["number g/p 45"])
    expect(github.calls).toEqual(["number o/r 7"])
  })

  test("rejects explicit targets on unconfigured hosts", async () => {
    expect(await locate(catalog({}), { directory: "/repo", target: target("https://github.example.com/o/r/pull/7") })).toEqual({
      kind: "none", reason: "Unsupported session target host",
    })
  })

  test("never falls back to the branch for an unresolved explicit target or an issue", async () => {
    const gitlab = new FakeForge("gitlab", undefined, [merge])
    const forges = catalog({ gitlab }, { repository: repository("gitlab.com") })
    expect(await locate(forges, { directory: "/repo", target: target(merge.url) })).toEqual({
      kind: "none", reason: "Explicit PR/MR target could not be resolved",
    })
    expect(await locate(forges, { directory: "/repo", target: target("https://gitlab.com/g/p/-/issues/3") })).toMatchObject({ kind: "none" })
    expect(gitlab.calls).toEqual(["number g/p 45"])
  })

  test("uses a title reference on the checkout's forge", async () => {
    expect(await locate(catalog({ gitlab: new FakeForge("gitlab", merge) }, { projects: onGitLab }), { directory: "/repo", title: "[#12, !45]" })).toMatchObject({
      sessionTarget: "!45 (from the session title)", requests: [merge],
    })
    expect(await locate(catalog({ github: new FakeForge("github", pull) }, { projects: onGitHub }), { directory: "/repo", title: "[#7]" })).toMatchObject({
      sessionTarget: "#7 (from the session title)", requests: [pull],
    })
  })

  test("skips title references that name issues, such as `[#42, #7]`", async () => {
    const github = new FakeForge("github", pull)
    const lookup = await locate(catalog({ github }, { projects: onGitHub }), { directory: "/repo", title: "[#42, #7]" })
    expect(lookup).toMatchObject({ requests: [pull] })
    expect(github.calls).toEqual(["number o/r 42", "number o/r 7"])
  })

  test("falls back to the branch when no title reference is a PR/MR", async () => {
    const gitlab = new FakeForge("gitlab", undefined, [merge])
    const forges = catalog({ gitlab }, { projects: onGitLab, repository: repository("gitlab.com") })
    // `#12` is a GitLab issue, and the checkout has no GitHub remote to check it on.
    expect(await locate(forges, { directory: "/repo", title: "[#12, !45]" })).toMatchObject({ requests: [merge] })
    expect(gitlab.calls).toEqual(["number g/p 45", "branch feature"])

    const github = new FakeForge("github", undefined, [pull])
    const issue = catalog({ github }, { projects: onGitHub, repository: repository("github.com") })
    expect(await locate(issue, { directory: "/repo", title: "[#42]" })).toMatchObject({ requests: [pull] })
    expect(github.calls).toEqual(["number o/r 42", "branch feature"])
  })

  test("dispatches branch lookups by the source remote's forge", async () => {
    const github = new FakeForge("github", undefined, [pull])
    const lookup = await locate(catalog({ github }, { repository: repository("github.com") }), { directory: "/repo" })
    expect(lookup).toMatchObject({ kind: "found", requests: [pull] })
    expect(github.calls).toEqual(["branch feature"])
    expect(await locate(catalog({ github }), { directory: "/repo" })).toEqual({ kind: "none", reason: "Not a Git repository" })
  })
})
