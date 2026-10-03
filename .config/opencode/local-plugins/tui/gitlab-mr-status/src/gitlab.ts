import type { Exec } from "./exec"
import type { RemoteProject, Repository } from "./git"

export interface Pipeline {
  status: string
  label: string
  url?: string
}

export interface MergeRequest {
  iid: string
  title: string
  url: string
  // opened, merged, closed, or locked.
  state: string
  draft: boolean
  conflicts: boolean
  approved: boolean
  mergeStatus?: string
  targetProject: string
  targetBranch: string
  headSha?: string
  updatedAt?: string
  pipeline?: Pipeline
  unresolvedThreads: number
  // False when more discussion pages exist than the plugin fetches.
  threadsComplete: boolean
}

export type ErrorKind = "auth" | "rate-limit" | "missing-glab" | "request"

export class GitLabError extends Error {
  constructor(
    readonly kind: ErrorKind,
    message: string,
  ) {
    super(message)
  }
}

interface DiscussionPage {
  pageInfo: { hasNextPage: boolean; endCursor: string | null }
  nodes: Array<{ resolvable: boolean; resolved: boolean }>
}

interface MergeRequestNode {
  iid: string
  title: string
  webUrl: string
  state: string
  draft: boolean
  conflicts: boolean
  approved: boolean | null
  detailedMergeStatus: string | null
  diffHeadSha: string | null
  updatedAt: string | null
  targetBranch: string
  sourceProject: { fullPath: string } | null
  targetProject: { fullPath: string }
  headPipeline: { status: string; path: string | null; detailedStatus: { label: string | null } | null } | null
  discussions: DiscussionPage
}

const DISCUSSIONS = "pageInfo { hasNextPage endCursor } nodes { resolvable resolved }"
const PAGE_SIZE = 100
export const MAX_DISCUSSION_PAGES = 50

const MERGE_REQUEST_FIELDS = `
  iid title webUrl state draft conflicts approved detailedMergeStatus diffHeadSha updatedAt targetBranch
  sourceProject { fullPath }
  targetProject { fullPath }
  headPipeline { status path detailedStatus { label } }
  discussions(first: ${PAGE_SIZE}) { ${DISCUSSIONS} }
`

export function mergeRequestsQuery(projectCount: number): string {
  const variables = Array.from({ length: projectCount }, (_, index) => `$p${index}: ID!`).join(", ")
  const projects = Array.from(
    { length: projectCount },
    (_, index) =>
      `p${index}: project(fullPath: $p${index}) {
        mergeRequests(sourceBranches: [$branch], state: opened, first: 20) { nodes { ${MERGE_REQUEST_FIELDS} } }
      }`,
  ).join("\n")
  return `query($branch: String!, ${variables}) {\n${projects}\n}`
}

export function mergeRequestQuery(projectCount: number): string {
  const variables = Array.from({ length: projectCount }, (_, index) => `$p${index}: ID!`).join(", ")
  const projects = Array.from(
    { length: projectCount },
    (_, index) => `p${index}: project(fullPath: $p${index}) { mergeRequest(iid: $iid) { ${MERGE_REQUEST_FIELDS} } }`,
  ).join("\n")
  return `query($iid: String!, ${variables}) {\n${projects}\n}`
}

export const DISCUSSIONS_QUERY = `query($project: ID!, $iid: String!, $after: String) {
  project(fullPath: $project) {
    mergeRequest(iid: $iid) { discussions(first: ${PAGE_SIZE}, after: $after) { ${DISCUSSIONS} } }
  }
}`

export function classifyError(message: string, code: number): GitLabError {
  const text = message.trim().replace(/^glab:\s*/, "") || `glab exited with code ${code}`
  if (/ENOENT|command not found/i.test(text)) return new GitLabError("missing-glab", "glab is not installed")
  if (/\b401\b|unauthori[sz]ed|not logged in|authenticat|invalid token|token.*expired/i.test(text)) {
    return new GitLabError("auth", "GitLab authentication failed. Run `glab auth status`.")
  }
  if (/\b429\b|rate limit|too many requests/i.test(text)) return new GitLabError("rate-limit", "GitLab rate limit reached")
  return new GitLabError("request", text.split("\n")[0])
}

export type GraphQL = (host: string, query: string, variables: Record<string, string>) => Promise<any>

export function glabGraphQL(run: Exec, cwd: string): GraphQL {
  return async (host, query, variables) => {
    const args = ["api", "graphql", "--hostname", host, "-f", `query=${query}`]
    for (const [name, value] of Object.entries(variables)) args.push("-f", `${name}=${value}`)
    const result = await run("glab", args, cwd)
    let body: any
    try {
      body = JSON.parse(result.stdout)
    } catch {
      throw classifyError(result.stderr, result.code)
    }
    if (body?.errors?.length && !body.data) throw classifyError(String(body.errors[0]?.message ?? ""), result.code)
    if (result.code !== 0 && !body?.data) throw classifyError(result.stderr, result.code)
    return body.data
  }
}

const countUnresolved = (page: DiscussionPage) =>
  page.nodes.filter((discussion) => discussion.resolvable && !discussion.resolved).length

async function unresolvedThreads(graphql: GraphQL, host: string, node: MergeRequestNode) {
  let count = countUnresolved(node.discussions)
  let page = node.discussions.pageInfo
  let pages = 1
  while (page.hasNextPage && page.endCursor && pages < MAX_DISCUSSION_PAGES) {
    const data = await graphql(host, DISCUSSIONS_QUERY, {
      project: node.targetProject.fullPath,
      iid: node.iid,
      after: page.endCursor,
    })
    const next: DiscussionPage | undefined = data?.project?.mergeRequest?.discussions
    if (!next) break
    count += countUnresolved(next)
    page = next.pageInfo
    pages++
  }
  return { count, complete: !page.hasNextPage }
}

export async function findMergeRequests(
  graphql: GraphQL,
  repository: Repository,
): Promise<MergeRequest[]> {
  const { source, targets, sourceBranch } = repository
  const variables: Record<string, string> = { branch: sourceBranch }
  targets.forEach((target, index) => (variables[`p${index}`] = target.path))
  const data = await graphql(source.host, mergeRequestsQuery(targets.length), variables)

  const sourcePath = source.path.toLowerCase()
  const seen = new Set<string>()
  const nodes: MergeRequestNode[] = []
  targets.forEach((_, index) => {
    for (const node of (data?.[`p${index}`]?.mergeRequests?.nodes ?? []) as MergeRequestNode[]) {
      // Another project's branch with the same name must not be reported as this branch's MR.
      if (node.sourceProject?.fullPath.toLowerCase() !== sourcePath) continue
      const key = `${node.targetProject.fullPath}!${node.iid}`
      if (seen.has(key)) continue
      seen.add(key)
      nodes.push(node)
    }
  })

  const requests = await Promise.all(nodes.map((node) => toMergeRequest(graphql, source.host, node)))
  return requests.sort((a, b) => (b.updatedAt ?? "").localeCompare(a.updatedAt ?? ""))
}

// Looks up one MR by number in each candidate project and returns the match
// from the first project that has it, so `origin` wins over other remotes.
export async function findMergeRequestByIid(
  graphql: GraphQL,
  projects: RemoteProject[],
  iid: string,
): Promise<MergeRequest | undefined> {
  const host = projects[0].host
  const variables: Record<string, string> = { iid }
  projects.forEach((project, index) => (variables[`p${index}`] = project.path))
  const data = await graphql(host, mergeRequestQuery(projects.length), variables)
  for (let index = 0; index < projects.length; index++) {
    const node: MergeRequestNode | undefined = data?.[`p${index}`]?.mergeRequest ?? undefined
    if (node) return toMergeRequest(graphql, host, node)
  }
  return undefined
}

async function toMergeRequest(graphql: GraphQL, host: string, node: MergeRequestNode): Promise<MergeRequest> {
  const threads = await unresolvedThreads(graphql, host, node)
  const pipeline = node.headPipeline
  return {
    iid: node.iid,
    title: node.title,
    url: node.webUrl,
    state: node.state.toLowerCase(),
    draft: node.draft,
    conflicts: node.conflicts,
    approved: node.approved === true,
    mergeStatus: node.detailedMergeStatus ?? undefined,
    targetProject: node.targetProject.fullPath,
    targetBranch: node.targetBranch,
    headSha: node.diffHeadSha ?? undefined,
    updatedAt: node.updatedAt ?? undefined,
    pipeline: pipeline
      ? {
          status: pipeline.status,
          label: pipeline.detailedStatus?.label ?? pipeline.status.toLowerCase().replace(/_/g, " "),
          url: pipeline.path ? `https://${host}${pipeline.path}` : undefined,
        }
      : undefined,
    unresolvedThreads: threads.count,
    threadsComplete: threads.complete,
  }
}
