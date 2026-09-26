// Blocks recursive forced deletes from agent shell commands with a message that
// points the agent at `trash`. opencode.json also has a `"rm -rf *": "deny"`
// permission rule as a backstop, which uses OpenCode's shell scanner but can
// only return a bare `permission.rejected` error. If the rule turns out to run
// before this hook, this message never shows, and the two need reconciling.

const ALTERNATIVE =
  process.platform === "darwin" ? "such as `trash`" : "such as moving it to a scratch directory for the user to review"
const MESSAGE = `Refusing to run \`rm -rf\` without user supervision. YOU MUST do it in a non-destructive way (${ALTERNATIVE}) or ask for permission. DO NOT attempt to work around this instruction.`

// Command separators: newlines, `;`, `&`, `|`, subshells, and substitutions
const SEGMENT_SPLIT = /[\n;&|()`]|\$\(/
// Wrappers that run the next word as the command
const WRAPPERS = new Set(["sudo", "command", "builtin", "exec", "nohup", "time", "env", "xargs", "doas"])

const isRecursiveForce = (args) => {
  let recursive = false
  let force = false
  for (const arg of args) {
    if (arg === "--") break
    if (arg === "--recursive") recursive = true
    else if (arg === "--force") force = true
    else if (/^-[a-zA-Z]+$/.test(arg)) {
      if (/[rR]/.test(arg)) recursive = true
      if (arg.includes("f")) force = true
    }
  }
  return recursive && force
}

const isRmRf = (segment) => {
  const words = segment.trim().split(/\s+/).filter(Boolean)
  let i = 0
  // Skip wrappers, their options, and leading VAR=value assignments
  while (i < words.length && (WRAPPERS.has(words[i]) || /^-/.test(words[i]) || /^[A-Za-z_][A-Za-z0-9_]*=/.test(words[i]))) i++
  const cmd = words[i]
  if (!cmd || cmd.replace(/^.*\//, "").replace(/^\\/, "") !== "rm") return false
  return isRecursiveForce(words.slice(i + 1))
}

// Blank out quoted strings so separators and words inside them (like a grep
// pattern `'a|rm -rf'`) aren't read as commands
const QUOTED = /'[^']*'|"(?:[^"\\]|\\.)*"/g

const check = (command = "") => {
  if (command.replace(QUOTED, "''").split(SEGMENT_SPLIT).some(isRmRf)) throw new Error(MESSAGE)
}

export default {
  id: "deny-rm-rf",
  async setup(ctx) {
    await ctx.tool.hook("execute.before", (event) => {
      if (event.tool === "shell") check(event.input?.command)
    })
  },
}
