import { describe, expect, test } from "bun:test"
import type { Plugin } from "@opencode/plugin"
import type { ReviewRef } from "./forge"
import { traits } from "./forges"
import type { TitleLookups } from "./lookups"
import { setupServer } from "./server"

type Tool = { execute: (input: unknown, context: { sessionID: string }) => Promise<unknown> }
type Hook = (event: { sessionID: string; system: { type: string; text: string }[] }) => Promise<void>

interface Options {
  storage?: Map<string, unknown>
  branch?: { current: string; default: string }
  // What the checkout's forge reports for the branch.
  found?: { branch: string; number?: string }
  sourceBranches?: Map<string, string>
  failingSession?: boolean
  pluginOptions?: Record<string, unknown>
}

async function harness(options: Options = {}) {
  const storage = options.storage ?? new Map<string, unknown>()
  const sessions = new Map([
    ["one", { title: "[#123, !45] Review changes", location: { directory: "/repo" }, parentID: undefined as string | undefined }],
    ["two", { title: "Other session", location: { directory: "/repo" }, parentID: undefined as string | undefined }],
  ])
  const sourceLookups: ReviewRef[] = []
  const lookups: TitleLookups = {
    branch: async () => (options.found ? { forge: traits("gitlab"), ...options.found } : undefined),
    sourceBranch: async (ref) => {
      sourceLookups.push(ref)
      return options.sourceBranches?.get(ref.iid)
    },
  }
  let tool!: Tool
  let hook!: Hook
  let renames = 0
  let handlers: Record<string, (input: unknown) => Promise<unknown>> = {}
  const emitted: Array<{ name: string; data: unknown }> = []
  const disposed: string[] = []
  const ctx = {
    rpc: {
      register: async (_definition: unknown, implementation: typeof handlers) => {
        handlers = implementation
        return {
          events: { emit: async (name: string, data: unknown) => void emitted.push({ name, data }) },
          dispose: async () => void disposed.push("rpc"),
        }
      },
    },
    location: { directory: "/repo" },
    options: options.pluginOptions ?? {},
    storage: {
      get: async (key: string) => storage.get(key),
      set: async (key: string, value: unknown) => void storage.set(key, value),
    },
    session: {
      get: async ({ sessionID }: { sessionID: string }) => {
        if (options.failingSession) throw new Error("unavailable")
        return sessions.get(sessionID)
      },
      update: async ({ sessionID, title }: { sessionID: string; title: string }) => {
        sessions.get(sessionID)!.title = title
        renames++
      },
      hook: async (_name: string, callback: Hook) => {
        hook = callback
      },
    },
    tool: {
      transform: async (callback: (editor: { add: (value: Tool) => void }) => void) => {
        callback({ add: (value) => (tool = value) })
        return { dispose: async () => void disposed.push("tool") }
      },
    },
    vcs: { get: async () => ({ data: { branch: options.branch ?? { current: "main", default: "main" } } }) },
    event: { subscribe: async function* () {} },
  }
  const cleanup = await setupServer(ctx as unknown as Plugin.Context, lookups)
  return {
    sessions,
    cleanup,
    emitted,
    disposed,
    sourceLookups,
    renames: () => renames,
    target: (sessionID = "one") => handlers.target!({ sessionID }),
    options: () => handlers.options!({}),
    set: (input: unknown, sessionID = "one") => tool.execute(input, { sessionID }),
    context: async (sessionID = "one") => {
      const event = { sessionID, system: [] as { type: string; text: string }[] }
      await hook(event)
      return event.system.map((part) => part.text).join("\n")
    },
  }
}

const mr = "https://gitlab.com/group/project/-/merge_requests/456"
const nextMr = "https://gitlab.com/group/project/-/merge_requests/789"
const issue = "https://gitlab.com/group/project/-/issues/42"

describe("session targets", () => {
  test("registers guidance and replaces branch references even on main", async () => {
    const app = await harness()
    expect(await app.context()).toContain("call set_session_target")
    await app.set({ target: mr })
    expect(app.sessions.get("one")?.title).toBe("[!456] Review changes")
    expect(await app.context()).toContain(mr)
    expect(await app.context("two")).not.toContain(mr)
    expect(app.sessions.get("two")?.title).toBe("Other session")
    await app.cleanup()
  })

  test("persists the target and owned prefix across plugin reloads", async () => {
    const storage = new Map<string, unknown>()
    const first = await harness({ storage })
    await first.set({ target: mr, issue_url: issue })
    const title = first.sessions.get("one")!.title
    await first.cleanup()

    const second = await harness({ storage })
    second.sessions.get("one")!.title = title
    expect(await second.context()).toContain(mr)
    await second.set({ target: nextMr })
    expect(second.sessions.get("one")?.title).toBe("[!789] Review changes")
    await second.set({ target: nextMr })
    expect(second.renames()).toBe(1)
    await second.cleanup()
  })

  test("reset removes the prefix on main and restores automatic context", async () => {
    const app = await harness()
    await app.set({ target: mr })
    await app.set({ target: "branch" })
    expect(app.sessions.get("one")?.title).toBe("Review changes")
    expect(await app.context()).toContain("checked-out branch (automatic)")
    await app.cleanup()
  })

  test("serializes concurrent switches and drops the previous related issue", async () => {
    const app = await harness()
    await Promise.all([app.set({ target: mr, issue_url: issue }), app.set({ target: nextMr })])
    expect(app.sessions.get("one")?.title).toBe("[!789] Review changes")
    await app.cleanup()
  })

  test("rejects invalid targets without changing the current target", async () => {
    const app = await harness()
    await app.set({ target: mr })
    await expect(app.set({ target: "!789" })).rejects.toThrow()
    expect(app.sessions.get("one")?.title).toBe("[!456] Review changes")
    expect(await app.context()).toContain(mr)
    await app.cleanup()
  })

  test("targets a newly created MR with its issue", async () => {
    const app = await harness()
    expect(await app.context()).toContain("After you create a PR or MR for the current task")
    await app.set({ target: "https://gitlab.com/group/project/-/issues/123" })
    expect(app.sessions.get("one")?.title).toBe("[#123] Review changes")
    await app.set({ target: mr, issue_url: "https://gitlab.com/group/project/-/issues/123" })
    expect(app.sessions.get("one")?.title).toBe("[#123, !456] Review changes")
    await app.cleanup()
  })

  test("infers the related issue from the MR source branch", async () => {
    const app = await harness({ sourceBranches: new Map([["456", "321-fix-timeout"]]) })
    await app.set({ target: mr })
    expect(app.sourceLookups).toEqual([{ forge: "gitlab", host: "gitlab.com", project: "group/project", iid: "456" }])
    expect(app.sessions.get("one")?.title).toBe("[#321, !456] Review changes")
    expect(await app.context()).toContain('"branchIssue":"321"')
    await app.set({ target: nextMr })
    expect(app.sessions.get("one")?.title).toBe("[!789] Review changes")
    await app.cleanup()
  })

  test("prefers an explicit issue and skips lookups for issue targets", async () => {
    const app = await harness({ sourceBranches: new Map([["456", "321-fix-timeout"]]) })
    await app.set({ target: mr, issue_url: "https://gitlab.com/group/other/-/issues/42" })
    expect(app.sessions.get("one")?.title).toBe("[#42, !456] Review changes")
    await app.set({ target: "https://gitlab.com/group/project/-/issues/7" })
    expect(app.sessions.get("one")?.title).toBe("[#7] Review changes")
    expect(app.sourceLookups).toEqual([])
    await app.cleanup()
  })

  test("exposes the target over RPC and announces changes", async () => {
    const storage = new Map<string, unknown>()
    const app = await harness({ storage })
    expect(await app.target()).toEqual({})
    await app.set({ target: mr, issue_url: issue })
    expect(await app.target()).toEqual({ url: mr, issueUrl: issue })
    expect(await app.target("two")).toEqual({})
    await app.set({ target: "branch" })
    expect(await app.target()).toEqual({})
    expect(app.emitted).toEqual([
      { name: "targetChanged", data: { sessionID: "one", url: mr, issueUrl: issue } },
      { name: "targetChanged", data: { sessionID: "one" } },
    ])
    await app.cleanup()
    expect(app.disposed).toEqual(["tool", "rpc"])

    const reloaded = await harness({ storage })
    await reloaded.set({ target: nextMr })
    expect(await reloaded.target()).toEqual({ url: nextMr })
    await reloaded.cleanup()
  })

  test("skips child sessions and sessions in another location", async () => {
    const app = await harness()
    app.sessions.get("one")!.parentID = "parent"
    expect(await app.context()).toBe("")
    await expect(app.set({ target: mr })).rejects.toThrow("root session")
    app.sessions.get("two")!.location.directory = "/another/location"
    expect(await app.context("two")).toBe("")
    await expect(app.set({ target: mr }, "two")).rejects.toThrow("root session")
    await app.cleanup()
  })

  test("serves the CLI's options, so reviewStatus can turn the CLI off", async () => {
    const app = await harness({ pluginOptions: { reviewStatus: false, pollSeconds: 60, unrelated: true } })
    expect(await app.options()).toEqual({ reviewStatus: false, pollSeconds: 60 })
    await app.set({ target: mr })
    expect(app.sessions.get("one")?.title).toBe("[!456] Review changes")
    await app.cleanup()
    expect(await (await harness()).options()).toEqual({})
  })

  test("never blocks the model request when the session can't be read", async () => {
    const app = await harness({ failingSession: true })
    expect(await app.context()).toBe("")
    await app.cleanup()
  })
})

describe("branch-based naming", () => {
  const feature = { current: "123-fix-login", default: "main" }

  test("prefixes the branch's issue and PR/MR", async () => {
    const app = await harness({ branch: feature, found: { branch: "123-fix-login", number: "45" } })
    await app.set({ target: "branch" })
    expect(app.sessions.get("one")?.title).toBe("[#123, !45] Review changes")
    await app.cleanup()
  })

  test("shows a placeholder until the PR/MR exists", async () => {
    const app = await harness({ branch: { current: "tidy-up", default: "main" }, found: { branch: "tidy-up" } })
    await app.set({ target: "branch" })
    expect(app.sessions.get("one")?.title).toBe("[tidy-up, !N/A] Review changes")
    await app.cleanup()
  })

  test("leaves the title alone without a forge remote", async () => {
    const app = await harness({ branch: feature })
    await app.set({ target: "branch" })
    expect(app.sessions.get("one")?.title).toBe("Review changes")
    await app.cleanup()
  })

  test("skips the default branch", async () => {
    const app = await harness({ branch: { current: "trunk", default: "trunk" }, found: { branch: "trunk", number: "1" } })
    await app.set({ target: "branch" })
    expect(app.sessions.get("one")?.title).toBe("Review changes")
    await app.cleanup()
  })
})
