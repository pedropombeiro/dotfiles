---
name: opencode-refine
description: "Iteratively test and refine prompts, skills, and agent configurations using opencode run"
version: 1.0.0
license: MIT
compatibility: opencode
metadata:
  audience: general
  workflow: local
---

# OpenCode Refine

Use `opencode run` as a fast feedback loop to test and refine prompts, system instructions, skills, and agent behavior without starting interactive sessions.

## When to Use

- Testing whether a system prompt change produces the desired agent behavior
- Refining a skill's instructions until the agent follows them correctly
- Debugging permission rules or config changes
- Validating agent output format or tone after configuration changes

## Core Command

```bash
opencode run --standalone '<prompt>'
```

Runs a single non-interactive agent session. The agent executes, prints its response, and exits. No TUI, no interactive approval.

`--standalone` starts a private server for the run. Without it, `opencode run` talks to the shared background service. That service reloads watched config directories on its own, but it does not see your shell environment, and edits to unwatched plugin dependencies only apply after `opencode service restart`.

**Important:** Make prompts self-contained and unambiguous. If the agent decides it needs to ask a clarifying question, `opencode run` will hang (see [Known Limitations](#known-limitations)).

**Prerequisite:** Prompts that invoke shell commands (e.g. "run ls -al") require the shell permission (`bash` in V1-style config, `shell` in V2 `permissions`) to resolve to `allow`. If it resolves to `ask`, the request is auto-rejected in non-interactive mode unless you pass `--auto`, which approves everything that is not explicitly denied.

## Useful Flags

| Flag | Purpose |
|------|---------|
| `-m <model>` | Override model (e.g. `-m gitlab/duo-chat-gpt-5-4-nano` for fast/cheap iterations) |
| `--standalone` | Use a private server that reads fresh config (see Core Command) |
| `--print-logs` | Show debug logs on stderr (permission checks, plugin hooks, config resolution); server logs need `--standalone` |
| `-f <file>` | Attach a file as context (repeatable) |
| `--format json` | Machine-readable event stream for scripting |
| `--auto` | Approve permission requests that are not explicitly denied |
| `--continue` | Continue the last session (multi-turn refinement) |
| `--session <id>` | Continue a specific session by ID |
| `--title <name>` | Give the session a human-readable name |

## Workflow

1. Write a self-contained prompt that exercises the behavior you want to refine
2. Run `opencode run`, observe the result, and iterate quickly
3. Use `--print-logs` when the issue is config, permissions, or plugin loading
4. Run from the repository (`cd <repo> && opencode run --standalone ...`) when you need to validate repo-specific config behavior

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

Agents can invoke `opencode run` inside `opencode run` via the `shell` tool:

```bash
opencode run --standalone 'use opencode run to test if date works: opencode run --standalone "run date and tell me the time"'
```

**What happens:**
- The inner `opencode run` is a subprocess called via the shell tool
- Each invocation starts a fresh session (no state shared)
- Both sessions use the same `opencode.json`
- Inner session output appears in the outer session's shell tool block

**Gotcha:** If the inner prompt triggers the `question` tool, the inner session hangs, and the outer session's shell tool will block waiting for it. Keep inner prompts self-contained.

## Example: Attaching Files

```bash
opencode run -f /path/to/file.md 'summarize this file'

# Multiple files
opencode run -f file1.md -f file2.md 'compare these files'
```

## Tips

- **Keep prompts self-contained**: Avoid vague prompts that might cause the agent to ask clarifying questions, which hangs the process (see Known Limitations).
- **Use `--standalone` for isolated runs**: each `opencode run --standalone` invocation starts its own server with your current environment and config. Plain `opencode run` goes through the shared background service.
- **Cheap models for iteration**: Use `-m gitlab/duo-chat-gpt-5-4-nano` when testing infrastructure (permissions, plugins). Switch to your primary model for testing prompt/tone quality.
- **Stderr for logs, stdout for output**: `--print-logs` writes to stderr, so you can `2>debug.log` and still see the agent's response on stdout.
- **Stdin piping**: `echo "prompt" | opencode run` works, which is useful for multi-line prompts or scripted input.

## Known Limitations

See `references/LIMITATIONS.md` for the `question`-tool hang, permission caveats, and config file locations.
