import type { GraphQL } from "./gitlab"

export interface FeedbackNote {
  // The numeric note ID. GitLab's global ID prefix changes with the note's
  // type, for example when a reply turns a comment into a discussion.
  id: string
  url: string
  // When the note was last written, in milliseconds. Resolving a thread also
  // updates it, but resolved threads are skipped.
  editedAt: number
  resolved: boolean
  system: boolean
  bot: boolean
  authorID: string
  username: string
}

export interface FeedbackSnapshot {
  // False when a page is missing or the viewer is unknown. A complete snapshot
  // covers every comment, or the newest MAX_FEEDBACK_PAGES pages of them.
  complete: boolean
  viewerID?: string
  notes: FeedbackNote[]
}

interface NoteNode {
  id: string
  url: string | null
  createdAt: string
  updatedAt: string | null
  lastEditedAt: string | null
  system: boolean
  discussion: { resolved: boolean } | null
  author: { id: string; username: string; bot: boolean } | null
}

const PAGE_SIZE = 100
// The newest comments the plugin reads. New comments and replies are always
// the newest, so older ones only matter as activity.
export const MAX_FEEDBACK_PAGES = 20

// ONLY_COMMENTS leaves out system notes such as "added 1 commit". Pages run
// backwards from the newest comment, in creation order within each page.
export const FEEDBACK_QUERY = `query($project: ID!, $iid: String!, $before: String) {
  currentUser { id }
  project(fullPath: $project) {
    mergeRequest(iid: $iid) {
      notes(last: ${PAGE_SIZE}, before: $before, filter: ONLY_COMMENTS) {
        pageInfo { hasPreviousPage startCursor }
        nodes {
          id url createdAt updatedAt lastEditedAt system
          discussion { resolved }
          author { id username bot }
        }
      }
    }
  }
}`

const noteNumber = (id: string) => id.slice(id.lastIndexOf("/") + 1)

const timestamp = (node: NoteNode) => Date.parse(node.lastEditedAt ?? node.updatedAt ?? node.createdAt)

export function toFeedbackNote(node: NoteNode): FeedbackNote | undefined {
  const editedAt = timestamp(node)
  const id = noteNumber(node.id)
  if (!node.author || !Number.isFinite(editedAt) || !/^\d+$/.test(id)) return undefined
  return {
    id,
    url: node.url ?? "",
    editedAt,
    resolved: node.discussion?.resolved === true,
    system: node.system,
    bot: node.author.bot,
    authorID: node.author.id,
    username: node.author.username,
  }
}

// Reads the MR's newest comments, oldest first, or undefined when the MR
// doesn't exist.
export async function fetchFeedback(
  graphql: GraphQL,
  host: string,
  project: string,
  iid: string,
): Promise<FeedbackSnapshot | undefined> {
  const pages: FeedbackNote[][] = []
  let viewerID: string | undefined
  let before: string | undefined
  const snapshot = (complete: boolean): FeedbackSnapshot => ({
    // Without the viewer's ID, their own comments can't be told apart.
    complete: complete && viewerID !== undefined,
    viewerID,
    notes: pages.toReversed().flat(),
  })
  for (let page = 0; page < MAX_FEEDBACK_PAGES; page++) {
    const variables: Record<string, string> = { project, iid }
    if (before) variables.before = before
    const data = await graphql(host, FEEDBACK_QUERY, variables)
    viewerID ??= data?.currentUser?.id ?? undefined
    const connection = data?.project?.mergeRequest?.notes
    if (!connection) return page === 0 ? undefined : snapshot(false)
    pages.push((connection.nodes as NoteNode[]).flatMap((node) => toFeedbackNote(node) ?? []))
    if (!connection.pageInfo.hasPreviousPage) return snapshot(true)
    before = connection.pageInfo.startCursor ?? undefined
    if (!before) return snapshot(false)
  }
  // A full window is complete: anything older is outside what the plugin watches.
  return snapshot(true)
}
