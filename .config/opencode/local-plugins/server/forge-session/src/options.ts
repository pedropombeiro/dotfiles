// The options that the CLI entry point reads. OpenCode passes the plugin's
// `opencode.json` options to the server entry point, so the CLI asks the
// server for them over RPC.
const CLI_OPTIONS = [
  "reviewStatus",
  "hosts",
  "githubHosts",
  "pollSeconds",
  "notifyAutomatedReviews",
  "notifyDuoReview",
  "notifyHumanReviews",
] as const

export type CliOptions = Partial<Record<(typeof CLI_OPTIONS)[number], unknown>>

// The CLI options among a plugin's options, so the RPC returns nothing else.
export function cliOptions(options: unknown): CliOptions {
  const source = options && typeof options === "object" ? (options as Record<string, unknown>) : {}
  return Object.fromEntries(CLI_OPTIONS.filter((key) => source[key] !== undefined).map((key) => [key, source[key]]))
}

const sleep = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms))

// Reads the server's options, retrying briefly in case the server entry point
// is still loading. The server's values win over the CLI's own options, which
// also cover a server that never answers.
export async function resolveCliOptions(
  local: unknown,
  fetch: () => Promise<unknown>,
  { attempts = 3, wait = sleep }: { attempts?: number; wait?: (ms: number) => Promise<void> } = {},
): Promise<CliOptions> {
  for (let attempt = 0; attempt < attempts; attempt++) {
    try {
      return { ...cliOptions(local), ...cliOptions(await fetch()) }
    } catch {}
    if (attempt < attempts - 1) await wait(250 * 2 ** attempt)
  }
  return cliOptions(local)
}

// `reviewStatus: false` turns off the CLI entry point, which leaves only the
// server's session targets and titles.
export const reviewStatusEnabled = (options: CliOptions) => options.reviewStatus !== false
