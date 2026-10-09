import { randomUUID } from "node:crypto"
import { mkdir, readFile, rename, unlink, writeFile } from "node:fs/promises"
import { homedir } from "node:os"
import { dirname, join } from "node:path"

type Object = Record<string, unknown>

function object(value: unknown): Object {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("CLI configuration and session settings must be JSON objects")
  }
  return value as Object
}

// OpenCode reads OPENCODE_CLI_CONFIG_CONTENT as JSONC, and cli.base.json carries
// comments, so the inline value needs a tolerant parse. This drops line and block
// comments and trailing commas, and copies strings through untouched so a value
// such as "https://opencode.ai" survives. cli.json stays on strict JSON.parse
// because toggle() rewrites it and would silently discard comments.
export function parseJsonc(text: string): unknown {
  let out = ""
  let i = 0
  while (i < text.length) {
    const char = text[i]!
    if (char === '"') {
      let end = i + 1
      while (end < text.length && text[end] !== '"') end += text[end] === "\\" ? 2 : 1
      out += text.slice(i, end + 1)
      i = end + 1
    } else if (char === "/" && text[i + 1] === "/") {
      while (i < text.length && text[i] !== "\n") i++
    } else if (char === "/" && text[i + 1] === "*") {
      const end = text.indexOf("*/", i + 2)
      if (end < 0) throw new SyntaxError("Unterminated block comment")
      out += " "
      i = end + 2
    } else {
      // A comma left right before a closing bracket is a trailing comma.
      if (char === "}" || char === "]") out = out.replace(/,\s*$/, "")
      out += char
      i++
    }
  }
  return JSON.parse(out)
}

export function override(env: NodeJS.ProcessEnv, argv: string[]) {
  if (argv.includes("--auto")) return "Restart OpenCode without --auto to change permission mode"
  if (!env.OPENCODE_CLI_CONFIG_CONTENT) return
  const config = object(parseJsonc(env.OPENCODE_CLI_CONFIG_CONTENT))
  if (config.session !== undefined && object(config.session).permissions !== undefined) {
    return "Remove session.permissions from OPENCODE_CLI_CONFIG_CONTENT to change permission mode"
  }
}

export function configPath(env: NodeJS.ProcessEnv = process.env) {
  return join(env.XDG_CONFIG_HOME || join(homedir(), ".config"), "opencode", "cli.json")
}

export async function toggle(path: string) {
  const text = await readFile(path, "utf8").catch((err: NodeJS.ErrnoException) => {
    if (err.code === "ENOENT") return "{}"
    throw err
  })
  const config = object(JSON.parse(text))
  const session = config.session === undefined ? {} : object(config.session)
  if (session.permissions !== undefined && !["prompt", "autoaccept"].includes(String(session.permissions))) {
    throw new Error("Unrecognized session.permissions value")
  }
  const mode = session.permissions === "autoaccept" ? "prompt" : "autoaccept"
  config.session = { ...session, permissions: mode }
  const temp = `${path}.${randomUUID()}.tmp`
  await mkdir(dirname(path), { recursive: true })
  try {
    await writeFile(temp, `${JSON.stringify(config, null, 2)}\n`, { mode: 0o600 })
    await rename(temp, path)
  } finally {
    await unlink(temp).catch((err: NodeJS.ErrnoException) => {
      if (err.code !== "ENOENT") throw err
    })
  }
  return mode
}
