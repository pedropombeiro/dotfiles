import type { ReviewRef } from "./forge"
import { parseReference, parseUrl, traits } from "./forges"
import type { TargetOutput } from "./rpc"

// A session's explicit target, as set_session_target stores it. `branchIssue`
// is the issue number in the PR/MR's source branch name, which the title shows
// when no `issueUrl` was given.
// A type alias rather than an interface, so it is assignable to plugin storage's JSON type.
export type Target = {
  url: string
  issueUrl?: string
  branchIssue?: string
}

interface Reference {
  url: string
  ref: ReviewRef
  issue: boolean
}

const INVALID_URL = "Use a full HTTP(S) issue, pull request, or merge request URL."

// Validates a target URL and normalizes it, dropping the query, the fragment,
// and a trailing slash, so equivalent links store the same target.
function parseTargetUrl(value: string): Reference {
  let url: URL
  try {
    url = new URL(value)
  } catch {
    throw new Error(INVALID_URL)
  }
  if (!["https:", "http:"].includes(url.protocol) || url.username || url.password) throw new Error(INVALID_URL)
  url.search = ""
  url.hash = ""
  url.pathname = url.pathname.replace(/\/$/, "")
  const parsed = parseReference(url.href)
  if (!parsed) throw new Error("Use a GitHub or GitLab issue, pull request, or merge request URL.")
  return { url: url.href, ...parsed }
}

// Parses set_session_target's input. Undefined means automatic branch mode.
export function parseTarget(input: unknown): Target | undefined {
  if (!input || typeof input !== "object" || !("target" in input) || typeof input.target !== "string") {
    throw new Error('Provide a target URL or "branch".')
  }
  const issueUrl = "issue_url" in input ? input.issue_url : undefined
  if (input.target === "branch") {
    if (issueUrl !== undefined) throw new Error("Branch mode does not accept issue_url.")
    return undefined
  }
  const target = parseTargetUrl(input.target)
  if (issueUrl === undefined) return { url: target.url }
  if (typeof issueUrl !== "string") throw new Error("issue_url must be a full issue URL.")
  const issue = parseTargetUrl(issueUrl)
  if (target.issue || !issue.issue || target.ref.forge !== issue.ref.forge) {
    throw new Error("Only a pull or merge request can have a related issue from the same forge.")
  }
  return { url: target.url, issueUrl: issue.url }
}

// The PR/MR a target names, or undefined for an issue.
export function targetRequest(target: Target): ReviewRef | undefined {
  const { ref, issue } = parseTargetUrl(target.url)
  return issue ? undefined : ref
}

// The title prefix for a target, such as `[#12, !45]`.
export function targetPrefix(target: Target): string {
  const { ref, issue } = parseTargetUrl(target.url)
  const forge = traits(ref.forge)
  const related = target.issueUrl
    ? (() => {
        const { ref: issueRef } = parseTargetUrl(target.issueUrl)
        return traits(issueRef.forge).issueReference(issueRef.iid)
      })()
    : !issue && target.branchIssue
      ? forge.issueReference(target.branchIssue)
      : undefined
  const main = issue ? forge.issueReference(ref.iid) : forge.reference(ref.iid)
  return `[${related ? `${related}, ` : ""}${main}]`
}

export const targetOutput = (target: Target | undefined): TargetOutput =>
  target ? { url: target.url, ...(target.issueUrl ? { issueUrl: target.issueUrl } : {}) } : {}

export type SessionTarget = { kind: "merge-request"; ref: ReviewRef } | { kind: "other"; url: string }

// Classifies the `target` RPC output. Undefined means the session has no
// explicit target; "other" is an explicit target that isn't a PR/MR, such as an issue.
export function classifyTarget(output: unknown): SessionTarget | undefined {
  const url = (output as { url?: unknown } | undefined)?.url
  if (typeof url !== "string" || !url) return undefined
  const ref = parseUrl(url)
  return ref ? { kind: "merge-request", ref } : { kind: "other", url }
}
