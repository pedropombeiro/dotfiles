import type { MergeRequest, Pipeline } from "./gitlab"
import type { Snapshot } from "./store"

export type Tone = "muted" | "success" | "warning" | "error"

export interface Segment {
  text: string
  tone: Tone
  url?: string
}

const RUNNING = new Set([
  "CREATED",
  "WAITING_FOR_RESOURCE",
  "PREPARING",
  "PENDING",
  "RUNNING",
  "SCHEDULED",
  "WAITING_FOR_CALLBACK",
  "CANCELING",
])

export function pipelineTone(pipeline: Pipeline | undefined): Tone {
  if (!pipeline) return "muted"
  if (pipeline.status === "FAILED") return "error"
  if (pipeline.status === "SUCCESS") return pipeline.label.includes("warning") ? "warning" : "success"
  if (RUNNING.has(pipeline.status)) return "warning"
  return "muted"
}

const plural = (count: number, word: string) => `${count} ${word}${count === 1 ? "" : "s"}`

function threadsText(mr: MergeRequest) {
  return `${mr.unresolvedThreads}${mr.threadsComplete ? "" : "+"} unresolved thread${mr.unresolvedThreads === 1 && mr.threadsComplete ? "" : "s"}`
}

export function footerSegments(snapshot: Snapshot): Segment[] {
  const { lookup, error } = snapshot
  if (!lookup || lookup.kind === "none") {
    return error ? [{ text: "MR status unavailable", tone: "warning" }] : []
  }

  const requests = lookup.mergeRequests
  if (requests.length === 0) return error ? [{ text: "MR status unavailable", tone: "warning" }] : []

  const segments: Segment[] = []
  if (requests.length > 1) {
    for (const mr of requests) segments.push({ text: `!${mr.iid}`, tone: "muted", url: mr.url })
    segments.push({ text: `${plural(requests.length, "open MR")}, run /mr-status`, tone: "warning" })
  } else {
    const [mr] = requests
    segments.push({ text: `!${mr.iid}`, tone: "muted", url: mr.url })
    if (mr.state !== "opened") {
      segments.push({ text: mr.state, tone: mr.state === "merged" ? "success" : "muted" })
      if (error) segments.push({ text: "stale", tone: "warning" })
      return segments
    }
    segments.push({
      text: mr.pipeline ? `CI ${mr.pipeline.label}` : "no pipeline",
      tone: pipelineTone(mr.pipeline),
      url: mr.pipeline?.url,
    })
    if (mr.unresolvedThreads > 0 || !mr.threadsComplete) segments.push({ text: threadsText(mr), tone: "warning" })
    if (mr.duoReviewState === "REVIEW_STARTED") segments.push({ text: "🤖 reviewing", tone: "warning" })
    if (mr.conflicts) segments.push({ text: "conflicts", tone: "error" })
    if (mr.approved) segments.push({ text: "approved", tone: "success" })
  }
  if (error) segments.push({ text: "stale", tone: "warning" })
  return segments
}

const yesNo = (value: boolean) => (value ? "yes" : "no")
const time = (value: number) => new Date(value).toLocaleTimeString()

function describe(mr: MergeRequest, head: string): string[] {
  const lines = [
    `!${mr.iid} ${mr.title}${mr.state === "opened" ? "" : ` (${mr.state})`}`,
    `Target: ${mr.targetProject} → ${mr.targetBranch}`,
    `Pipeline: ${mr.pipeline ? mr.pipeline.label : "none"}${mr.pipeline?.url ? ` (${mr.pipeline.url})` : ""}`,
    `Unresolved threads: ${mr.unresolvedThreads}${mr.threadsComplete ? "" : "+"}`,
    `Draft: ${yesNo(mr.draft)} · Conflicts: ${yesNo(mr.conflicts)}`,
    `Has approvals: ${yesNo(mr.hasApprovals)} · Approval requirements satisfied: ${mr.approvalRequirementsSatisfied === null ? "unknown" : yesNo(mr.approvalRequirementsSatisfied)}`,
  ]
  if (mr.mergeStatus) lines.push(`Merge status: ${mr.mergeStatus.toLowerCase().replace(/_/g, " ")}`)
  if (mr.duoReviewState) lines.push(`Duo review: ${mr.duoReviewState.toLowerCase().replace(/_/g, " ")}`)
  if (head && mr.headSha && head !== mr.headSha) {
    lines.push("Local HEAD differs from the MR head commit (unpushed or not fetched)")
  }
  lines.push(mr.url)
  return lines
}

export function detailsMessage(snapshot: Snapshot): string {
  const { lookup, error, fetchedAt } = snapshot
  const lines: string[] = []

  if (!lookup) {
    lines.push(error ? "Could not look up the merge request." : "No data yet.")
  } else if (lookup.kind === "none") {
    lines.push(`No merge request lookup: ${lookup.reason}.`)
  } else {
    const { repository, sessionTarget, mergeRequests } = lookup
    if (repository) {
      const branch =
        repository.branch === repository.sourceBranch
          ? repository.branch
          : `${repository.branch} (pushes to ${repository.sourceBranch})`
      lines.push(`Branch: ${branch} in ${repository.source.path}`)
      if (mergeRequests.length === 0) lines.push("", "No open merge request for this branch.")
    } else if (sessionTarget) {
      lines.push(`Session target: ${sessionTarget}`)
    }
    for (const mr of mergeRequests) lines.push("", ...describe(mr, repository?.head ?? ""))
  }

  if (error) lines.push("", `Last refresh failed at ${time(error.at)}: ${error.message}`)
  if (fetchedAt !== undefined) lines.push("", `Last fetched: ${time(fetchedAt)}`)
  return lines.join("\n")
}
