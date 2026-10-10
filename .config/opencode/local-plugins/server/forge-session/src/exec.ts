import { execFile } from "node:child_process"

export interface ExecResult {
  stdout: string
  stderr: string
  code: number
}

export type Exec = (file: string, args: string[], cwd: string) => Promise<ExecResult>

// Runs a command without a shell, so arguments are never reinterpreted.
export const execWithTimeout =
  (timeout: number): Exec =>
  (file, args, cwd) =>
    new Promise((resolve) => {
      execFile(file, args, { cwd, timeout, maxBuffer: 16 * 1024 * 1024, encoding: "utf8" }, (error, stdout, stderr) => {
        if (!error) return resolve({ stdout, stderr, code: 0 })
        const code = typeof error.code === "number" ? error.code : -1
        resolve({ stdout, stderr: stderr || error.message, code })
      })
    })

export const exec = execWithTimeout(30_000)
