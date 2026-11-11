import { realpath, stat } from "node:fs/promises"
import { basename, isAbsolute, relative, resolve, sep } from "node:path"
import { latestFile } from "./tail"

interface Tool {
  type: string
  name?: string
  state?: { status?: string; input?: Record<string, unknown> }
}
export interface Message { content?: Tool[] }
interface Page<T> { data: T[]; cursor: { next?: string | null } }
export interface Source {
  messages(id: string, cursor?: string): Promise<Page<Message>>
  children(id: string, cursor?: string): Promise<Page<{ id: string }>>
}

// This deliberately recognizes common shell writes, not arbitrary shell programs.
// Quoted tokens stay intact; only unquoted operators split commands.
function shellWrites(command: string): string[] {
  const tokens = [...command.matchAll(/(?:"(?:\\.|[^"\\])*"|'[^']*'|[^\s;&|<>"']+)+|[;&|<>]+|\n/g)]
    .map(([raw]) => ({ raw, value: raw.replace(/"((?:\\.|[^"\\])*)"|'([^']*)'/g, (_, double, single) => single ?? double.replace(/\\(["\\$`])/g, "$1")) }))
  const paths: string[] = []
  const variables = new Map<string, string>()
  let logAssignments: string[] = []
  const expand = (value: string): string => value.replace(/\$\{([A-Za-z_][A-Za-z0-9_]*)\}|\$([A-Za-z_][A-Za-z0-9_]*)/g,
    (match, braced, plain) => variables.get(braced ?? plain) ?? match)
  let args: string[] = []
  const flush = () => {
    const name = basename(args[0] ?? "")
    const operands = args.slice(1).filter((arg) => !arg.startsWith("-"))
    // Log destinations are often passed into a script rather than redirected here.
    // Only count assignments on executable commands, not a standalone declaration.
    if (args.length && name !== "export") paths.push(...logAssignments)
    if (["tee", "touch", "mkdir"].includes(name)) paths.push(...operands)
    if (["cp", "mv", "install"].includes(name) && operands.length >= 2) paths.push(operands.at(-1)!)
    args = []
    logAssignments = []
  }
  for (let i = 0; i < tokens.length; i++) {
    const token = tokens[i]!
    if (/^[;&|]+$/.test(token.raw) || token.raw === "\n") { flush(); continue }
    if (/^>+$/.test(token.raw)) {
      const target = tokens[++i]
      if (target) paths.push(expand(target.value))
      continue
    }
    if (token.raw.includes("<")) {
      // Do not mistake heredoc content for executable shell commands.
      if (token.raw.includes("<<")) { flush(); break }
      i++
      continue
    }
    const assignment = token.value.match(/^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/s)
    if (assignment && (!args.length || args[0] === "export")) {
      const value = expand(assignment[2]!)
      variables.set(assignment[1]!, value)
      // Explicit log variables on a command invocation associate its output.
      if (/^[A-Z_]*LOG$/.test(assignment[1]!)) logAssignments.push(value)
      continue
    }
    args.push(expand(token.value))
  }
  flush()
  return paths
}

export function writtenPaths(message: Message): string[] {
  const paths: string[] = []
  for (const tool of message.content ?? []) {
    if (tool.type !== "tool" || !["running", "completed"].includes(tool.state?.status ?? "")) continue
    const input = tool.state?.input ?? {}
    const name = tool.name?.replace(/^functions\./, "")
    if (["write", "edit"].includes(name ?? "")) {
      const path = input.path ?? input.file_path ?? input.filePath
      if (typeof path === "string") paths.push(path)
    }
    if (["patch", "apply_patch"].includes(name ?? "")) {
      const patch = input.patchText ?? input.patch
      if (typeof patch === "string") {
        for (const match of patch.matchAll(/^\*\*\* (?:Add File|Update File|Move to): (.+)$/gm)) paths.push(match[1]!)
      }
    }
    if (["shell", "bash"].includes(name ?? "") && typeof input.command === "string") {
      for (const path of shellWrites(input.command)) {
        paths.push(!isAbsolute(path) && !path.startsWith("$") && typeof input.workdir === "string" ? resolve(input.workdir, path) : path)
      }
    }
  }
  return paths
}

async function pages<T>(load: (cursor?: string) => Promise<Page<T>>): Promise<T[]> {
  const values: T[] = []
  const seen = new Set<string>()
  let cursor: string | undefined
  for (let page = 0; page < 1000; page++) {
    const result = await load(cursor)
    values.push(...result.data)
    if (!result.cursor.next) return values
    if (seen.has(result.cursor.next)) throw new Error("Repeated pagination cursor")
    cursor = result.cursor.next
    seen.add(cursor)
  }
  throw new Error("Session history exceeds the pagination limit")
}

export async function sessionFile(directory: string, sessionID: string, source: Source): Promise<string | undefined> {
  const root = await realpath(directory).catch(() => resolve(directory))
  const contains = (path: string) => {
    const suffix = relative(root, path)
    return suffix !== ".." && !suffix.startsWith(`..${sep}`) && !isAbsolute(suffix)
  }
  const queue = [sessionID]
  const visited = new Set<string>()
  const candidates = new Set<string>()
  while (queue.length) {
    const id = queue.shift()!
    if (visited.has(id)) continue
    visited.add(id)
    const [messages, children] = await Promise.all([
      pages((cursor) => source.messages(id, cursor)),
      pages((cursor) => source.children(id, cursor)),
    ])
    queue.push(...children.map((child) => child.id))
    for (const message of messages) {
      for (const raw of writtenPaths(message)) {
        const expanded = raw.replace(/^\$(?:TMPDIR|\{TMPDIR\})(?=\/|$)/, resolve(directory, ".."))
        if (!isAbsolute(expanded)) continue
        const path = await realpath(expanded).catch(() => undefined)
        if (path && contains(path)) candidates.add(path)
      }
    }
  }
  let latest: { path: string; mtime: number } | undefined
  for (const candidate of candidates) {
    try {
      const info = await stat(candidate)
      const path = info.isDirectory() ? await latestFile(candidate) : info.isFile() ? candidate : undefined
      if (!path) continue
      const mtime = (await stat(path)).mtimeMs
      if (!latest || mtime > latest.mtime || (mtime === latest.mtime && path < latest.path)) latest = { path, mtime }
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error
    }
  }
  return latest?.path
}

export async function preferredFile(directory: string, sessionID: string | undefined, source: Source): Promise<string | undefined> {
  return (sessionID ? await sessionFile(directory, sessionID, source) : undefined) ?? await latestFile(directory)
}
