import { execFile } from "node:child_process"
import { readdir, stat } from "node:fs/promises"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { promisify } from "node:util"

const exec = promisify(execFile)
const marker = "@opencode-tail"
export const tailCommand = 'if command -v bat >/dev/null 2>&1; then tail -F "$1" | bat --paging=never --color=always --style=plain --file-name "$1"; else exec tail -F "$1"; fi'

export async function latestFile(directory: string): Promise<string | undefined> {
  let latest: { path: string; mtime: number } | undefined
  async function visit(directory: string) {
    let entries
    try {
      entries = await readdir(directory, { withFileTypes: true })
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code === "ENOENT") return
      throw error
    }
    for (const entry of entries) {
      const path = join(directory, entry.name)
      if (entry.isDirectory()) {
        await visit(path)
      } else if (entry.isFile()) {
        try {
          const info = await stat(path)
          if (!latest || info.mtimeMs > latest.mtime || (info.mtimeMs === latest.mtime && path < latest.path)) {
            latest = { path, mtime: info.mtimeMs }
          }
        } catch (error) {
          if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error
        }
      }
    }
  }
  await visit(directory)
  return latest?.path
}

export type Toast = { message: string; variant: "success" | "warning" | "error" }
export type RunTmux = (args: string[]) => Promise<string>

const runTmux: RunTmux = async (args) => (await exec("tmux", args)).stdout.trim()

export async function toggleTail(
  env: NodeJS.ProcessEnv = process.env,
  run: RunTmux = runTmux,
  findLatest = latestFile,
): Promise<Toast> {
  if (!env.TMUX || !env.TMUX_PANE) {
    return { message: "Run OpenCode inside tmux to tail a temp file.", variant: "warning" }
  }
  try {
    const owner = env.TMUX_PANE
    const panes = await run(["list-panes", "-t", owner, "-F", `#{pane_id}\t#{${marker}}`])
    const existing = panes.split("\n").find((line) => line.split("\t")[1] === owner)?.split("\t")[0]
    if (existing) {
      await run(["kill-pane", "-t", existing])
      return { message: "Closed temp-file tail pane.", variant: "success" }
    }

    const directory = join(env.TMPDIR || tmpdir(), "opencode")
    const file = await findLatest(directory)
    if (!file) return { message: `No files found in ${directory}.`, variant: "warning" }

    // Pass the filename as a positional argument, never interpolate it into shell code.
    const pane = await run([
      "split-window", "-v", "-d", "-l", "30%", "-t", owner,
      "-P", "-F", "#{pane_id}", "--", "sh", "-c", tailCommand, "opencode-tail", file,
    ])
    try {
      await run(["set-option", "-p", "-t", pane, marker, owner])
      await run(["set-option", "-p", "-t", pane, "remain-on-exit", "off"])
    } catch (error) {
      await run(["kill-pane", "-t", pane]).catch(() => {})
      throw error
    }
    return { message: `Following ${file}`, variant: "success" }
  } catch (error) {
    return { message: `Could not toggle temp-file tail: ${error instanceof Error ? error.message : String(error)}`, variant: "error" }
  }
}
