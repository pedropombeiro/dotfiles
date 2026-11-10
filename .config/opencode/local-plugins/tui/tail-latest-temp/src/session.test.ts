import { afterEach, expect, test } from "bun:test"
import { mkdir, mkdtemp, realpath, rm, symlink, utimes, writeFile } from "node:fs/promises"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { preferredFile, sessionFile, writtenPaths, type Message, type Source } from "./session"

const directories: string[] = []
afterEach(async () => {
  await Promise.all(directories.splice(0).map((path) => rm(path, { recursive: true, force: true })))
})
const tool = (name: string, input: Record<string, unknown>, status = "completed"): Message => ({
  content: [{ type: "tool", name, state: { status, input } }],
})

test("collects write/edit/patch destinations, excluding reads, failed calls, and patch deletions", () => {
  expect(writtenPaths(tool("write", { path: "/temp/a" }))).toEqual(["/temp/a"])
  expect(writtenPaths(tool("edit", { filePath: "/temp/b" }, "running"))).toEqual(["/temp/b"])
  expect(writtenPaths(tool("patch", { patchText: "*** Add File: /temp/a\n*** Update File: /temp/b\n*** Delete File: /temp/c" }))).toEqual(["/temp/a", "/temp/b"])
  expect(writtenPaths(tool("read", { path: "/temp/a" }))).toEqual([])
  expect(writtenPaths(tool("write", { path: "/temp/a" }, "error"))).toEqual([])
})

test("shell writes include redirect targets and common command destinations, not read operands", () => {
  expect(writtenPaths(tool("shell", { command: 'cat /temp/read > "/temp/new file" && cp /temp/source /temp/copy; tail -F /temp/read | tee -a /temp/log' })))
    .toEqual(["/temp/new file", "/temp/copy", "/temp/log"])
  expect(writtenPaths(tool("shell", { command: "cat /temp/read; tail -F /temp/read; bat /temp/read" }))).toEqual([])
  expect(writtenPaths(tool("shell", { command: "echo 'touch /temp/not-written'; cat > /temp/doc <<'EOF'\ntouch /temp/not-written\nEOF" })))
    .toEqual(["/temp/doc"])
  expect(writtenPaths(tool("shell", { command: "touch output.log", workdir: "/temp/opencode" }))).toEqual(["/temp/opencode/output.log"])
})

test("selects latest modified session/descendant write across pages with canonical paths and TMPDIR expansion", async () => {
  const base = await mkdtemp(join(tmpdir(), "opencode-session-test-"))
  directories.push(base)
  const directory = join(base, "opencode")
  await mkdir(directory)
  await symlink(directory, join(base, "alias"))
  for (const [name, time] of [["parent", 1000], ["child", 2000], ["read-only", 3000], ["global", 4000]] as const) {
    await writeFile(join(directory, name), name)
    await utimes(join(directory, name), time, time)
  }
  const calls: string[] = []
  const source: Source = {
    async messages(id, cursor) {
      calls.push(`${id}:${cursor ?? "first"}`)
      if (id === "parent" && !cursor) return { data: [tool("read", { path: join(directory, "read-only") })], cursor: { next: "older" } }
      return {
        data: [tool("write", { path: id === "parent" ? join(base, "alias", "parent") : "${TMPDIR}/opencode/child" })],
        cursor: {},
      }
    },
    async children(id) { return { data: id === "parent" ? [{ id: "child" }] : [], cursor: {} } },
  }
  expect(await sessionFile(directory, "parent", source)).toBe(await realpath(join(directory, "child")))
  expect(calls).toContain("parent:older")
  expect(calls).toContain("child:first")
})

test("ignores outside paths and missing writes, and resolves files inside written directories", async () => {
  const base = await mkdtemp(join(tmpdir(), "opencode-session-test-"))
  directories.push(base)
  const directory = join(base, "opencode")
  await mkdir(join(directory, "report"), { recursive: true })
  await writeFile(join(directory, "report", "out"), "")
  const source: Source = {
    async messages() {
      return { data: [tool("shell", { command: `mkdir '${directory}/report'; touch '${directory}/missing'; touch '${directory}/../../outside'` })], cursor: {} }
    },
    async children() { return { data: [], cursor: {} } },
  }
  expect(await sessionFile(directory, "parent", source)).toContain("report/out")
  source.messages = async () => ({ data: [tool("read", { path: join(directory, "report", "out") })], cursor: {} })
  expect(await sessionFile(directory, "parent", source)).toBeUndefined()
  expect(await preferredFile(directory, "parent", source)).toContain("report/out")
  source.messages = async () => { throw new Error("must not fetch on home screen") }
  expect(await preferredFile(directory, undefined, source)).toContain("report/out")
})

test("rejects pagination loops instead of silently falling back", async () => {
  const source: Source = {
    async messages() { return { data: [], cursor: { next: "loop" } } },
    async children() { return { data: [], cursor: {} } },
  }
  await expect(sessionFile("/missing/opencode", "parent", source)).rejects.toThrow("Repeated pagination cursor")
})
