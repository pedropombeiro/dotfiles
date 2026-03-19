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
| `-m <model>` | Override model (e.g. `-m gitlab/duo-chat-haiku-4-5` for fast/cheap iterations) |
| `--print-logs` | Show debug logs on stderr (permission checks, plugin hooks, config resolution) |
| `-f <file> --` | Attach a file as context — **requires `--` separator before the prompt** |
| `--format json` | Machine-readable event stream for scripting |
| `--dir <path>` | Run the session in a specific directory (inherits that directory's config) |
| `--continue` | Continue the last session (multi-turn refinement) |
| `--session <id>` | Continue a specific session by ID |
| `--title <name>` | Give the session a human-readable name |

## Workflow

### 1. Write a test prompt that exercises the behavior you're refining

The prompt should be specific enough to trigger the exact behavior you want to verify. Think of it as a test case.

```bash
# Bad: too vague — may cause the agent to ask clarifying questions (which hangs)
opencode run 'do something with files'

# Good: exercises the specific behavior, self-contained
opencode run 'run ls -al and tell me what you see'
```

### 2. Run, observe, adjust — tight loop

```bash
# Edit the config/skill/prompt
# Then immediately test:
opencode run 'your test prompt'

# Use a cheap model for faster iterations:
opencode run -m gitlab/duo-chat-haiku-4-5 'your test prompt'
```

### 3. Use --print-logs to debug infrastructure

When the agent's behavior is wrong but you're not sure why (wrong config loading, plugins not firing, permissions):

```bash
opencode run --print-logs 'your test prompt' 2>debug.log
# Review debug.log for:
# - Which config files were loaded (config.json, opencode.json, opencode.jsonc)
# - Session permissions that were applied
# - Tool registry startup
# - Bash command execution with input/output/exit code
```

### 4. Use --dir to test project-specific configs

Each directory can have its own `opencode.json`. Use `--dir` to test configs in context:

```bash
opencode run --dir ~/workspace/my-project 'run git status'
# Agent runs in ~/workspace/my-project, uses that project's opencode.json if present
```

## Example: Refining a System Prompt

```bash
# Edit ~/.config/opencode/agent/your-agent.md
# Then test the specific behavior you changed:

opencode run 'what tools do you have access to?'
# Check: does the agent describe its environment correctly?

opencode run 'I need help with a task'
# Check: does the agent follow the collaboration style you defined?
```

## Example: Testing Permissions

After editing permission rules in `opencode.json`:

```bash
# If bash is set to "ask" — will be auto-rejected in non-interactive mode
opencode run 'run git status'

# If bash is set to "allow" — will execute
opencode run 'run date'
```

**Note:** The behavior depends entirely on your `opencode.json` permission config. Check `~/.config/opencode/opencode.json` and use `--print-logs` to see which rules are applied.

## Example: Scripting with --format json

`--format json` emits a newline-delimited stream of typed events (no colored header):

```bash
# Extract just the text response
opencode run --format json 'what is 2+2?' | \
  python3 -c '
import sys, json
for line in sys.stdin:
    ev = json.loads(line.strip())
    if ev.get("type") == "text":
        print(ev["part"]["text"])
'

# Get token usage from a run
opencode run --format json 'run date' | \
  python3 -c '
import sys, json
for line in sys.stdin:
    ev = json.loads(line.strip())
    if ev.get("type") == "step_finish":
        print("tokens:", ev["part"]["tokens"])
'

# Capture session ID for continuation (first event with sessionID)
SESSION_ID=$(opencode run --format json 'set up scenario X' | \
  python3 -c '
import sys, json
for line in sys.stdin:
    ev = json.loads(line.strip())
    if "sessionID" in ev:
        print(ev["sessionID"])
        break
')
opencode run --session "$SESSION_ID" 'now test variation Y'
```

**Event types:**

| Type | Contains |
|------|----------|
| `step_start` | sessionID, messageID, partID |
| `text` | Agent text response chunks |
| `tool_use` | Tool name, input params, full output, exit code, duration |
| `step_finish` | Stop reason, token counts (input/output/cache/reasoning), cost |

## Example: Multi-Turn Refinement Loop

Use `--continue` to build context across multiple runs:

```bash
# Step 1: Set up scenario
opencode run 'I am working in directory /tmp/myproject. Run git init there.'

# Step 2: Test variations in the same session
opencode run --continue 'now create a README.md and commit it'

# Step 3: Verify final state
opencode run --continue 'run git log and show me what happened'
```

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
- **Cheap models for iteration**: Use `-m gitlab/duo-chat-haiku-4-5` when testing infrastructure (permissions, plugins). Switch to your primary model for testing prompt/tone quality.
- **Stderr for logs, stdout for output**: `--print-logs` writes to stderr, so you can `2>debug.log` and still see the agent's response on stdout.
- **Stdin piping**: `echo "prompt" | opencode run` works — useful for multi-line prompts or scripted input.

## Known Limitations

### question tool hangs in opencode run

The `question` tool is technically `deny`-listed in non-interactive mode, but due to a bug, if the agent calls it, the process hangs waiting for user input instead of auto-rejecting.

**Symptom:** `opencode run` takes unusually long and never exits.

**Workaround:** Write prompts that don't require clarification. If you must handle this, wrap calls with a timeout:

```bash
# Linux/GNU:
timeout 30 opencode run 'your prompt' || echo "Timed out — agent may have tried to ask a question"

# macOS (requires coreutils: brew install coreutils):
gtimeout 30 opencode run 'your prompt' || echo "Timed out — agent may have tried to ask a question"
```

### Permissions depend on your opencode.json

The skill's "Example: Testing Permissions" only applies if your `bash` permission is set to `"ask"`. Check your actual config:

```bash
cat ~/.config/opencode/opencode.json | python3 -m json.tool
```

### Config file locations

opencode checks multiple config files (first match wins for each setting):
1. `~/.config/opencode/opencode.json` — primary location
2. `~/.config/opencode/opencode.jsonc`
3. `~/.opencode/opencode.json`
4. `<workdir>/opencode.json`

Use `--print-logs` and grep for `service=config` to see which files are loaded.
