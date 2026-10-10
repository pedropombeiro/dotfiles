import { describe, expect, test } from "bun:test"
import { cliOptions, resolveCliOptions, reviewStatusEnabled } from "./options"

const noWait = async () => {}

describe("cliOptions", () => {
  test("keeps only the options the CLI reads", () => {
    expect(cliOptions({ reviewStatus: false, pollSeconds: 60, secret: "x", hosts: undefined })).toEqual({
      reviewStatus: false,
      pollSeconds: 60,
    })
    expect(cliOptions(undefined)).toEqual({})
    expect(cliOptions("nope")).toEqual({})
  })
})

describe("resolveCliOptions", () => {
  test("prefers the server's options over the CLI's own", async () => {
    const options = await resolveCliOptions({ reviewStatus: true, pollSeconds: 30 }, async () => ({ reviewStatus: false }))
    expect(options).toEqual({ reviewStatus: false, pollSeconds: 30 })
  })

  test("retries while the server is loading", async () => {
    const waits: number[] = []
    let calls = 0
    const options = await resolveCliOptions(
      {},
      async () => {
        if (++calls < 3) throw new Error("rpc not registered")
        return { reviewStatus: false }
      },
      { wait: async (ms) => void waits.push(ms) },
    )
    expect(options).toEqual({ reviewStatus: false })
    expect(waits).toEqual([250, 500])
  })

  test("falls back to the CLI's own options when the server never answers", async () => {
    const options = await resolveCliOptions({ notifyHumanReviews: false }, async () => {
      throw new Error("offline")
    }, { wait: noWait })
    expect(options).toEqual({ notifyHumanReviews: false })
  })
})

describe("reviewStatusEnabled", () => {
  test("is on unless explicitly turned off", () => {
    expect(reviewStatusEnabled({})).toBe(true)
    expect(reviewStatusEnabled({ reviewStatus: true })).toBe(true)
    expect(reviewStatusEnabled({ reviewStatus: "false" })).toBe(true)
    expect(reviewStatusEnabled({ reviewStatus: false })).toBe(false)
  })
})
