import { afterEach, expect, test } from "bun:test"
import { mkdtemp, mkdir, rm, symlink, utimes, writeFile } from "node:fs/promises"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { latestFile, tailCommand, toggleTail } from "./tail"

const directories: string[] = []
afterEach(async () => {
  await Promise.all(directories.splice(0).map((path) => rm(path, { recursive: true, force: true })))
})

async function fixture() {
  const path = await mkdtemp(join(tmpdir(), "opencode-tail-test-"))
  directories.push(path)
  return path
}

test("finds the latest modified regular file recursively, ignoring directories and symlinks", async () => {
  const directory = await fixture()
  await mkdir(join(directory, "nested"))
  await writeFile(join(directory, "old"), "old")
  const latest = join(directory, "nested", "latest's output.log")
  await writeFile(latest, "new")
  await utimes(join(directory, "old"), 1000, 1000)
  await utimes(latest, 2000, 2000)
  await symlink(directory, join(directory, "cycle"))
  expect(await latestFile(directory)).toBe(latest)
})

test("handles missing and empty directories", async () => {
  const directory = await fixture()
  expect(await latestFile(directory)).toBeUndefined()
  expect(await latestFile(join(directory, "missing"))).toBeUndefined()
})

test("breaks modification-time ties by path", async () => {
  const directory = await fixture()
  for (const name of ["b", "a"]) {
    await writeFile(join(directory, name), "")
    await utimes(join(directory, name), 1000, 1000)
  }
  expect(await latestFile(directory)).toBe(join(directory, "a"))
})

const env = { TMUX: "/socket,123,0", TMUX_PANE: "%1", TMPDIR: "/custom temp/" }

test("warns outside tmux without running commands", async () => {
  expect((await toggleTail({}, async () => { throw new Error("must not run") })).variant).toBe("warning")
})

test("opens a detached 30% bottom split using TMPDIR and literal argv", async () => {
  const calls: string[][] = []
  const file = "/custom temp/opencode/it's $(not-a-command).log"
  const result = await toggleTail(env, async (args) => {
    calls.push(args)
    return args[0] === "split-window" ? "%3" : "%1\t\n%2\t%99"
  }, async (directory) => {
    expect(directory).toBe("/custom temp/opencode")
    return file
  })
  expect(result.variant).toBe("success")
  expect(calls).toEqual([
    ["list-panes", "-t", "%1", "-F", "#{pane_id}\t#{@opencode-tail}"],
    ["split-window", "-v", "-d", "-l", "30%", "-t", "%1", "-P", "-F", "#{pane_id}", "--", "sh", "-c", tailCommand, "opencode-tail", file],
    ["set-option", "-p", "-t", "%3", "@opencode-tail", "%1"],
    ["set-option", "-p", "-t", "%3", "remain-on-exit", "off"],
  ])
})

test("closes only the owner's pane before looking for another file", async () => {
  const calls: string[][] = []
  await toggleTail(env, async (args) => {
    calls.push(args)
    return "%2\t%99\n%3\t%1"
  }, async () => { throw new Error("must not scan") })
  expect(calls[1]).toEqual(["kill-pane", "-t", "%3"])
  expect(calls).toHaveLength(2)
})

test("does not split when there are no files", async () => {
  const calls: string[][] = []
  const result = await toggleTail(env, async (args) => { calls.push(args); return "" }, async () => undefined)
  expect(result.variant).toBe("warning")
  expect(calls).toHaveLength(1)
})

test("reports tmux failures", async () => {
  const result = await toggleTail(env, async () => { throw new Error("no server") })
  expect(result).toEqual({ message: "Could not toggle temp-file tail: no server", variant: "error" })
})

test("cleans up the new pane if setting its options fails", async () => {
  const calls: string[][] = []
  const result = await toggleTail(env, async (args) => {
    calls.push(args)
    if (args[0] === "set-option") throw new Error("option failed")
    return args[0] === "split-window" ? "%3" : ""
  }, async () => "/temp/opencode/file")
  expect(result.variant).toBe("error")
  expect(calls.at(-1)).toEqual(["kill-pane", "-t", "%3"])
})
