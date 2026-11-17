import { expect, test } from "bun:test"
import { publisher } from "./publish"

test("publishes full titles as arguments, deduplicates, and clears on exit", async () => {
  const calls: string[][] = []
  let refreshed = 0
  const writer = publisher(async (args) => { calls.push(args) }, "%12", async () => { refreshed++ })
  const title = "[#123, !456] " + "A long session title; $(echo literal) ".repeat(5)
  writer.update(title)
  writer.update(title)
  writer.update("Another session")
  await writer.close()
  writer.update("Ignored after exit")
  expect(calls.filter((args) => args.includes("@opencode-full-title"))).toEqual([
    ["set-option", "-p", "-t", "%12", "@opencode-full-title", title],
    ["set-option", "-p", "-t", "%12", "@opencode-full-title", "Another session"],
    ["set-option", "-p", "-u", "-t", "%12", "@opencode-full-title"],
  ])
  expect(calls.filter((args) => args.includes("@opencode-attention"))).toHaveLength(3)
  expect(refreshed).toBe(3)
})

test("clears the override on home and serializes cleanup after failed writes", async () => {
  const calls: string[][] = []
  const writer = publisher(async (args) => {
    calls.push(args)
    if (args.at(-1) === "Fail") throw new Error("tmux unavailable")
  }, "%12", async () => {})
  writer.update("Session")
  writer.update(undefined)
  writer.update("Fail")
  await writer.close()
  expect(calls.filter((args) => args.includes("@opencode-full-title")).map((args) => args.includes("-u"))).toEqual([false, true, false, true])
})

test("publishes attention-only changes and clears both options on cleanup", async () => {
  const calls: string[][] = []
  const writer = publisher(async (args) => { calls.push(args) }, "%12", async () => {})
  writer.update("Session", "waiting")
  writer.update("Session", "waiting")
  writer.update("Session", "error")
  writer.update("Session")
  await writer.close()
  expect(calls.filter((args) => args.includes("@opencode-attention")).map((args) => args.slice(0, 3).includes("-u") ? undefined : args.at(-1))).toEqual(["waiting", "error", undefined, undefined])
  expect(calls.slice(-2).every((args) => args.includes("-u"))).toBe(true)
})
