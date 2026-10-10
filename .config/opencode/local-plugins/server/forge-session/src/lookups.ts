import type { Exec } from "./exec"
import type { ForgeTraits, ReviewRef } from "./forge"
import { traits, type ForgeCatalog } from "./forges"

// What session titles need from the forges. Status lookups in the CLI use the
// same catalog, so both agree on which remote, branch, and PR/MR a checkout has.
export interface TitleLookups {
  // The checked-out branch and the number of its newest open PR/MR. Undefined
  // when the checkout has no supported forge remote or is on its default branch.
  branch(directory: string): Promise<{ forge: ForgeTraits; branch: string; number?: string } | undefined>
  // The branch a PR/MR was opened from, for inferring its issue.
  sourceBranch(ref: ReviewRef, directory: string): Promise<string | undefined>
}

export function createTitleLookups(forges: ForgeCatalog, run: Exec): TitleLookups {
  // A branch's PR/MR rarely changes once it exists, so found numbers are kept.
  // A branch without one is looked up again after every turn.
  const numbers = new Map<string, string>()

  return {
    async branch(directory) {
      const lookup = await forges.repository(directory)
      if (lookup.kind === "none") return undefined
      const { repository } = lookup
      const forge = forges.forHost(repository.source.host, directory)
      if (!forge) return undefined
      const key = JSON.stringify([directory, repository.source.host, repository.source.path, repository.sourceBranch])
      let number = numbers.get(key)
      if (!number) {
        number = await forge.findNumberByBranch(repository).catch(() => undefined)
        if (number) numbers.set(key, number)
      }
      return { forge: forge.traits, branch: repository.branch, number }
    },

    // Uses the forge the URL names, even on a host the catalog doesn't list.
    async sourceBranch(ref, directory) {
      return traits(ref.forge).open(run, directory).sourceBranch(ref).catch(() => undefined)
    },
  }
}
