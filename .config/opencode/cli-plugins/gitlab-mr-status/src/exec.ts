import { execFile } from "node:child_process"

export interface ExecResult {
  stdout: string
  stderr: string
  code: number
}

export type Exec = (file: string, args: string[], cwd: string) => Promise<ExecResult>

export const exec: Exec = (file, args, cwd) =>
  new Promise((resolve) => {
    execFile(
      file,
      args,
      { cwd, timeout: 30_000, maxBuffer: 16 * 1024 * 1024, encoding: "utf8" },
      (error, stdout, stderr) => {
        if (!error) return resolve({ stdout, stderr, code: 0 })
        const code = typeof error.code === "number" ? error.code : -1
        resolve({ stdout, stderr: stderr || error.message, code })
      },
    )
  })
