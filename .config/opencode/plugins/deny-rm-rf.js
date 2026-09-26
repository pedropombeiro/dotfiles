// Blocks recursive forced deletes from agent shell commands with a message that
// points the agent at `trash`. opencode.json also has a `"rm -rf *": "deny"`
// permission rule as a backstop, which uses OpenCode's shell scanner but can
// only return a bare `permission.rejected` error. If the rule turns out to run
// before this hook, this message never shows, and the two need reconciling.
//
// This is a heuristic, not a shell parser. It covers command separators,
// line continuations, common wrappers and their options, command substitutions
// (including inside double quotes), and `sh -c` strings.

const ALTERNATIVE =
  process.platform === "darwin" ? "such as `trash`" : "such as moving it to a scratch directory for the user to review"
const MESSAGE = `Refusing to run \`rm -rf\` without user supervision. YOU MUST do it in a non-destructive way (${ALTERNATIVE}) or ask for permission. DO NOT attempt to work around this instruction.`

// Command separators: newlines, `;`, `&`, `|`, subshells, and substitutions
const SEGMENT_SPLIT = /[\n;&|()`]|\$\(/

// Wrappers that run a later word as the command, with the options of each that
// take a separate argument (`sudo -u root rm`), and how many positional
// arguments precede the command (`timeout 10 rm`).
const WRAPPERS = {
  builtin: { args: [] },
  command: { args: [] },
  doas: { args: ["-u", "-C"] },
  env: { args: ["-u", "-C", "-S", "-P"] },
  exec: { args: ["-a"] },
  ionice: { args: ["-c", "-n", "-t", "-p", "-P", "-u"] },
  nice: { args: ["-n"] },
  nohup: { args: [] },
  stdbuf: { args: ["-i", "-o", "-e"] },
  sudo: { args: ["-u", "-g", "-C", "-D", "-h", "-p", "-U", "-r", "-t", "-T"] },
  time: { args: ["-f", "-o"] },
  timeout: { args: ["-s", "-k"], positional: 1 },
  xargs: { args: ["-n", "-P", "-L", "-I", "-s", "-d", "-E", "-a", "-l"] },
}

const SINGLE_QUOTED = /'[^']*'/g
const DOUBLE_QUOTED = /"((?:[^"\\]|\\.)*)"/g
const SUBSTITUTION = /\$\(([^()]*)\)|`([^`]*)`/g
const SHELL_C = /\b(?:ba|z|da|k)?sh\s+(?:-[a-zA-Z]+\s+)*-[a-zA-Z]*c\s+(?:'([^']*)'|"((?:[^"\\]|\\.)*)")/g

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
  while (i < words.length) {
    // Leading VAR=value assignments
    if (/^[A-Za-z_][A-Za-z0-9_]*=/.test(words[i])) {
      i++
      continue
    }
    const wrapper = WRAPPERS[words[i]]
    if (!wrapper) break
    i++
    while (i < words.length && words[i].startsWith("-")) {
      const option = words[i++]
      if (option === "--") break
      if (wrapper.args.includes(option)) i++
    }
    i += wrapper.positional ?? 0
  }
  const cmd = words[i]
  if (!cmd || cmd.replace(/^.*\//, "").replace(/^\\/, "") !== "rm") return false
  return isRecursiveForce(words.slice(i + 1))
}

// Returns the command text to scan, with quoted strings reduced to what the
// shell would execute: single-quoted text is literal and dropped, and a
// double-quoted string keeps only its command substitutions.
const executableText = (command) =>
  command
    .replace(/\\\r?\n/g, " ")
    .replace(SINGLE_QUOTED, "''")
    .replace(DOUBLE_QUOTED, (_, body) => {
      const substitutions = [...body.matchAll(SUBSTITUTION)].map((m) => m[1] ?? m[2])
      return substitutions.length ? `;${substitutions.join(";")};` : "''"
    })

const check = (command = "", depth = 0) => {
  if (executableText(command).split(SEGMENT_SPLIT).some(isRmRf)) throw new Error(MESSAGE)
  // Commands passed to `sh -c` and friends are quoted, so check them separately
  if (depth < 2) {
    for (const m of command.matchAll(SHELL_C)) check(m[1] ?? m[2], depth + 1)
  }
}

export default {
  id: "deny-rm-rf",
  async setup(ctx) {
    await ctx.tool.hook("execute.before", (event) => {
      if (event.tool === "shell") check(event.input?.command)
    })
  },
}
