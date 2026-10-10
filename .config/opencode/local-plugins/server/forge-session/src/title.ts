import type { ForgeTraits } from "./forge"

// Prefixes that opencode-forge-session-title wrote before it tracked its own
// prefix, such as `[#12, !45] `.
const LEGACY_PREFIX_RE = /^\[[^[\],]+, [!#](?:\d+|N\/A)\] /
const MAX_TITLE_LENGTH = 100

const ISSUE_PATTERNS: RegExp[] = [
  /(?:^|[/])(\d+)[-/]/,
  /[-/](\d+)$/,
  /^(?:issue|gh|bug|fix|feat|feature|hotfix)[-/](\d+)\b/i,
]

// The issue number in a branch name, such as `123` in `feature/123-add-login`.
export function extractIssueNumber(branch: string): string | undefined {
  for (const pattern of ISSUE_PATTERNS) {
    const match = branch.match(pattern)
    if (match) return match[1]
  }
  return undefined
}

// Replaces the prefix this plugin last wrote, or a legacy one, with `prefix`.
// Text the user added, including their own bracketed prefixes, is kept.
export function reconcileTitle(title: string, prefix?: string, previousPrefix?: string): string {
  const rest =
    previousPrefix && title.startsWith(`${previousPrefix} `)
      ? title.slice(previousPrefix.length + 1)
      : title.replace(LEGACY_PREFIX_RE, "")
  return (prefix ? `${prefix} ${rest}` : rest).slice(0, MAX_TITLE_LENGTH)
}

// The prefix for branch-based naming: the branch's issue, or the branch name
// without one, and its PR/MR, or `!N/A` until one exists.
export function branchPrefix(forge: ForgeTraits, branch: string, number: string | undefined): string {
  const issue = extractIssueNumber(branch)
  return `[${issue ? forge.issueReference(issue) : branch}, ${forge.reference(number ?? "N/A")}]`
}
