import { afterEach, describe, expect, test } from "bun:test"
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { configPath, override, parseJsonc, toggle } from "./config"

const directories: string[] = []

async function fixture(text?: string) {
  const dir = await mkdtemp(join(tmpdir(), "opencode-permission-mode-"))
  directories.push(dir)
  const path = join(dir, "cli.json")
  if (text !== undefined) await writeFile(path, text)
  return path
}

afterEach(async () => {
  await Promise.all(directories.splice(0).map((dir) => rm(dir, { recursive: true })))
})

describe("permission mode", () => {
  test("toggles both ways without changing unrelated settings", async () => {
    const config = { theme: { name: "opencode" }, session: { permissions: "prompt", sidebar: "hide" } }
    const path = await fixture(JSON.stringify(config))
    expect(await toggle(path)).toBe("autoaccept")
    expect(JSON.parse(await readFile(path, "utf8"))).toEqual({
      ...config,
      session: { ...config.session, permissions: "autoaccept" },
    })
    expect(await toggle(path)).toBe("prompt")
    expect(JSON.parse(await readFile(path, "utf8"))).toEqual(config)
  })

  test("defaults to prompt when the setting or file is missing", async () => {
    const path = await fixture()
    expect(await toggle(path)).toBe("autoaccept")
    expect(await toggle(await fixture('{"session":{"sidebar":"hide"}}'))).toBe("autoaccept")
  })

  test("creates a missing configuration directory", async () => {
    const path = join(await fixture(), "..", "nested", "cli.json")
    expect(await toggle(path)).toBe("autoaccept")
    expect(JSON.parse(await readFile(path, "utf8"))).toEqual({ session: { permissions: "autoaccept" } })
  })

  test("leaves malformed or invalid configuration untouched", async () => {
    for (const text of [
      "{",
      "null",
      "[]",
      '{"session":null}',
      '{"session":[]}',
      '{"session":{"permissions":"unknown"}}',
    ]) {
      const path = await fixture(text)
      await expect(toggle(path)).rejects.toThrow()
      expect(await readFile(path, "utf8")).toBe(text)
    }
  })
})

describe("overrides", () => {
  test("detects forced CLI and environment modes", () => {
    expect(override({}, ["opencode", "--auto"])).toContain("--auto")
    expect(override({ OPENCODE_CLI_CONFIG_CONTENT: '{"session":{"permissions":"prompt"}}' }, [])).toContain(
      "OPENCODE_CLI_CONFIG_CONTENT",
    )
    expect(override({ OPENCODE_CLI_CONFIG_CONTENT: '{"session":{"permissions":"autoaccept"}}' }, [])).toBeDefined()
  })

  test("allows unrelated inline settings", () => {
    expect(override({}, [])).toBeUndefined()
    expect(override({ OPENCODE_CLI_CONFIG_CONTENT: '{"keybinds":{"agent.cycle":false}}' }, [])).toBeUndefined()
    expect(override({ OPENCODE_CLI_CONFIG_CONTENT: '{"session":{"sidebar":"hide"}}' }, [])).toBeUndefined()
  })

  test("accepts the commented JSONC that cli.base.json uses", () => {
    const content = `{
  // Comment with "quotes" and a trailing comma below.
  "$schema": "https://opencode.ai/v2/cli.json",
  "plugins": [
    "./local-plugins/tui/permission-mode", // Shift+Tab toggles the preference
    "./local-plugins/tui/session-metrics" /* block */,
  ],
}`
    expect(override({ OPENCODE_CLI_CONFIG_CONTENT: content }, [])).toBeUndefined()
    expect(override({ OPENCODE_CLI_CONFIG_CONTENT: content.replace('"plugins"', '"session": { "permissions": "prompt" },\n  "plugins"') }, [])).toContain(
      "OPENCODE_CLI_CONFIG_CONTENT",
    )
  })

  test("rejects malformed inline configuration", () => {
    expect(() => override({ OPENCODE_CLI_CONFIG_CONTENT: "{" }, [])).toThrow()
  })

  test("respects XDG_CONFIG_HOME", () => {
    expect(configPath({ XDG_CONFIG_HOME: "/custom/config" })).toBe("/custom/config/opencode/cli.json")
    expect(configPath({})).toEndWith("/.config/opencode/cli.json")
  })
})

describe("parseJsonc", () => {
  test("keeps comment markers and brackets inside strings", () => {
    expect(parseJsonc('{"url":"https://example.com/a//b","text":"/* x */","list":["a,]","b,}"]}')).toEqual({
      url: "https://example.com/a//b",
      text: "/* x */",
      list: ["a,]", "b,}"],
    })
  })

  test("handles escaped quotes, comments, and trailing commas", () => {
    expect(parseJsonc('{"a":"say \\"hi\\" // not a comment", // real comment\n "b":[1,2,], }')).toEqual({
      a: 'say "hi" // not a comment',
      b: [1, 2],
    })
    expect(parseJsonc("{ /* one */ \"a\": /* two */ 1 }")).toEqual({ a: 1 })
  })

  test("still rejects invalid input", () => {
    expect(() => parseJsonc("{")).toThrow()
    expect(() => parseJsonc('{"a": 1 /* open')).toThrow("Unterminated block comment")
    expect(() => parseJsonc('{"a": nope}')).toThrow()
  })
})
