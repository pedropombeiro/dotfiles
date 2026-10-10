import { traits, type ForgeCatalog } from "./forges"
import type { Lookup } from "./store"
import type { SessionTarget } from "./target"

export interface Hints {
  directory: string
  // The session's explicit target, stored by set_session_target.
  target?: SessionTarget
  // The session title, or just its managed prefix, such as `[#12, !45]`.
  title?: string
}

// Picks the session's PR/MR: the explicit target first, then a title
// reference, and finally the checked-out branch's open PRs/MRs.
export async function locate(forges: ForgeCatalog, hints: Hints): Promise<Lookup> {
  const { directory, target, title } = hints

  // An explicit target that isn't a PR/MR, such as an issue, means the session
  // isn't about one, so the branch's PR/MR would be misleading.
  if (target?.kind === "other") {
    return { kind: "none", reason: `The session target is not a PR/MR (${target.url})` }
  }
  if (target) {
    const { ref } = target
    const forge = forges.kind(ref.host) === ref.forge ? forges.forHost(ref.host, directory) : undefined
    if (!forge) return { kind: "none", reason: "Unsupported session target host" }
    const request = await forge.findByNumber([{ host: ref.host, path: ref.project }], ref.iid)
    if (request) return { kind: "found", sessionTarget: request.url, explicitTarget: true, requests: [request] }
    // Never fall back to the branch, which may have a different PR/MR.
    return { kind: "none", reason: "Explicit PR/MR target could not be resolved" }
  }

  // Each forge reads its own references from the title, on the forges the
  // checkout has remotes for. A reference can also name an issue, so it only
  // counts once the forge finds a PR/MR with that number.
  for (const kind of forges.kinds) {
    const numbers = traits(kind).titleReferences(title)
    if (numbers.length === 0) continue
    const projects = await forges.projects(directory, kind)
    const forge = projects.length ? forges.forHost(projects[0].host, directory) : undefined
    if (!forge) continue
    for (const number of numbers) {
      const request = await forge.findByNumber(projects, number)
      if (request) {
        return { kind: "found", sessionTarget: `${forge.traits.reference(number)} (from the session title)`, requests: [request] }
      }
    }
  }

  const lookup = await forges.repository(directory)
  if (lookup.kind === "none") return lookup
  const forge = forges.forHost(lookup.repository.source.host, directory)
  if (!forge) return { kind: "none", reason: "Not a supported forge remote" }
  return { kind: "found", repository: lookup.repository, requests: await forge.findByBranch(lookup.repository) }
}
