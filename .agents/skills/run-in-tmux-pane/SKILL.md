---
name: run-in-tmux-pane
description: Run commands in a temporary tmux pane with full interactive zsh environment (login shell, shims, PATH, aliases, TTY).
version: 1.0.0
license: MIT
compatibility: opencode
metadata:
  author: pedropombeiro
  audience: developers
---

# run-in-tmux-pane

Run a command in a temporary tmux pane that has the user's full interactive zsh environment.
The pane opens, runs the command, captures output, and closes automatically.

## Why use this skill

**Agent tools run in a non-interactive shell.** Commands that rely on your login
shell — autoloaded zsh functions, mise/asdf shims, custom `PATH` entries, shell
aliases — silently fail or are not found when invoked from a bare `bash -c`.
This skill gives the agent access to your real shell environment without
requiring the agent session itself to run inside zsh.

**Long command output wastes tokens.** Successful commands often produce
hundreds of lines the agent never needs. The script automatically truncates
successful output to the last 20 lines, keeping token usage low while still
returning the full output on failure so the agent can diagnose problems.

**Granting broad shell permissions is risky.** Instead of allowing the agent to
run arbitrary dangerous commands directly, you can wrap those commands in a
script and grant the agent permission to call `run-in-tmux-pane <script>` only.
The agent never needs direct access to the underlying tools — just to this
single entry point.

**Commands that need a TTY.** Some CLI tools (e.g. `claude`, interactive
installers) refuse to run without a TTY. The tmux pane provides one
transparently.

## When to use

- A command needs the user's full shell environment (PATH, shims, aliases, etc.)
- Running interactive CLI tools that need a TTY (e.g. `claude -p`)
- A tool is not found or misbehaves when run from a non-interactive shell

## Setup

The script is bundled at [scripts/run-in-tmux-pane](scripts/run-in-tmux-pane).
To make it available system-wide, symlink it onto your PATH:

```bash
ln -s "$(pwd)/scripts/run-in-tmux-pane" ~/.local/bin/run-in-tmux-pane
```

## Usage

**Quoting rule:** Only wrap the command in single quotes when it contains inner quotes
or special shell characters (`"`, `'`, `$`, `` ` ``, `\`). For simple commands with no
special characters, pass arguments directly (no outer quotes). This produces cleaner
command patterns for permission matching.

```bash
# Simple command — no inner quotes, pass directly (preferred)
run-in-tmux-pane mise doctor

# Command with inner quotes — wrap in single quotes
run-in-tmux-pane 'claude -p "Hello, how are you?"'
```

## How it works

1. Opens a tmux split-pane (30% height, detached)
2. Runs the command inside `zsh -ilc` (interactive login shell)
3. Waits for the pane to close
4. Returns captured stdout and stderr with ANSI escape codes stripped
5. Exits with the command's exit code

## Output behavior

- If the command succeeds and output exceeds 20 lines, only the last 20 lines are shown
  (with a truncation notice)
- If the command fails, the full output is returned
- ANSI escape sequences are stripped from the output
- `TMUX_PANE_LINGER` controls how many seconds the tmux pane stays visible after the
  command finishes (default: 3). Set to 0 to close immediately.

## Examples

```bash
# Run a CLI tool that needs shims/PATH — no quotes needed
run-in-tmux-pane mise doctor

# Ask Claude a question — inner quotes require outer single quotes
run-in-tmux-pane 'claude --print "Explain this error: undefined method foo"'

# Run a command that needs shell aliases — no quotes needed
run-in-tmux-pane gdk start rails
```

## Configuration

| Variable | Default | Description |
|---|---|---|
| `TMUX_PANE_LINGER` | `3` | Seconds to keep the tmux pane visible after the command finishes. Set to `0` to close immediately. |
| `TMUX_PANE_TAIL_LINES` | `20` | Number of trailing lines to keep when truncating successful output. |
| `TMUX_PANE_TIMEOUT` | `120` | Maximum seconds to wait for the command to finish before killing the pane (exits with code 124). |

## Limitations

- Requires an active tmux session (`$TMUX` must be set)
- Cannot interact with the command after launch (no stdin) — use only for commands that
  run to completion on their own
- The command runs in the user's home directory by default (zsh -ilc behavior)
