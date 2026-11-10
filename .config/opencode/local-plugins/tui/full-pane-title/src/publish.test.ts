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
  expect(calls).toEqual([
    ["set-option", "-p", "-t", "%12", "@opencode-full-title", title],
    ["set-option", "-p", "-t", "%12", "@opencode-full-title", "Another session"],
    ["set-option", "-p", "-u", "-t", "%12", "@opencode-full-title"],
  ])
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
  expect(calls.map((args) => args.includes("-u"))).toEqual([false, true, false, true])
})
