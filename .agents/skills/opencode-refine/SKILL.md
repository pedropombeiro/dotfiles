---
name: opencode-refine
description: Iteratively test and refine prompts, skills, and agent configurations using opencode run
version: 1.0.0
license: MIT
compatibility: opencode
metadata:
  audience: general
  workflow: local
---

# OpenCode Refine

Use `opencode run` as a fast feedback loop to test and refine prompts, system instructions, skills, and agent behavior — without starting interactive sessions.

## When to Use

- Testing whether a system prompt change produces the desired agent behavior
- Refining a skill's instructions until the agent follows them correctly
- Debugging permission rules or config changes
- Validating agent output format or tone after configuration changes

## Core Command

```bash
opencode run '<prompt>'
```

Runs a single non-interactive agent session. The agent executes, prints its response, and exits. No TUI, no interactive approval.

**Important:** Make prompts self-contained and unambiguous. If the agent decides it needs to ask a clarifying question, `opencode run` will hang (see [Known Limitations](#known-limitations)).

**Prerequisite:** Prompts that invoke shell commands (e.g. "run ls -al") require `bash` permission set to `"allow"` in your `opencode.json`. If set to `"ask"`, they will be auto-rejected in non-interactive mode.

## Useful Flags

| Flag | Purpose |
|------|---------|
| `-m <model>` | Override model (e.g. `-m gitlab/duo-chat-gpt-5-4-nano` for fast/cheap iterations) |
| `--print-logs` | Show debug logs on stderr (permission checks, plugin hooks, config resolution) |
| `-f <file> --` | Attach a file as context — **requires `--` separator before the prompt** |
| `--format json` | Machine-readable event stream for scripting |
| `--dir <path>` | Run the session in a specific directory (inherits that directory's config) |
| `--continue` | Continue the last session (multi-turn refinement) |
| `--session <id>` | Continue a specific session by ID |
| `--title <name>` | Give the session a human-readable name |

## Workflow

1. Write a self-contained prompt that exercises the behavior you want to refine
2. Run `opencode run`, observe the result, and iterate quickly
3. Use `--print-logs` when the issue is config, permissions, or plugin loading
4. Use `--dir` when you need to validate repo-specific config behavior

See `references/EXAMPLES.md` for concrete commands and patterns.

See `references/EXAMPLES.md` for concrete examples covering system-prompt refinement, permissions, JSON output, and multi-turn refinement.

**Event types:**

| Type | Contains |
|------|----------|
| `step_start` | sessionID, messageID, partID |
| `text` | Agent text response chunks |
| `tool_use` | Tool name, input params, full output, exit code, duration |
| `step_finish` | Stop reason, token counts (input/output/cache/reasoning), cost |

## Example: Nested opencode run

Agents can invoke `opencode run` inside `opencode run` via the `bash` tool:

```bash
opencode run 'use opencode run to test if date works: opencode run "run date and tell me the time"'
```

**What happens:**
- The inner `opencode run` is a subprocess called via the bash tool
- Each invocation starts a fresh session (no state shared)
- Both sessions use the same `opencode.json`
- Inner session output appears in the outer session's bash tool block

**Gotcha:** If the inner prompt triggers the `question` tool, the inner session will hang — and the outer session's bash tool will block waiting for it. Keep inner prompts self-contained.

## Example: Attaching Files

```bash
# IMPORTANT: requires '--' separator before the prompt
opencode run -f /path/to/file.md -- 'summarize this file'

# Multiple files
opencode run -f file1.md -f file2.md -- 'compare these files'
```

Without the `--`, the CLI parser treats the prompt as a second file path and errors.

## Tips

- **Keep prompts self-contained**: Avoid vague prompts that might cause the agent to ask clarifying questions — that will hang the process (see Known Limitations).
- **Config changes are instant**: No restart needed. Each `opencode run` invocation reads fresh config.
- **Cheap models for iteration**: Use `-m gitlab/duo-chat-gpt-5-4-nano` when testing infrastructure (permissions, plugins). Switch to your primary model for testing prompt/tone quality.
- **Stderr for logs, stdout for output**: `--print-logs` writes to stderr, so you can `2>debug.log` and still see the agent's response on stdout.
- **Stdin piping**: `echo "prompt" | opencode run` works — useful for multi-line prompts or scripted input.

## Known Limitations

See `references/LIMITATIONS.md` for the `question`-tool hang, permission caveats, and config file locations.
