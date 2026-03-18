---
name: run-in-tmux-pane
description: >
  Run commands in a temporary tmux pane with full interactive zsh environment.
  Use when a command needs the user's full shell environment (login shell, mise/asdf shims,
  custom PATH, shell aliases), or when running interactive CLI tools (like `claude`) that
  require a TTY. Keywords: tmux, shell, interactive, tty, zsh, environment, shims.
license: MIT
compatibility: opencode
metadata:
  author: pedropombeiro
---

# run-in-tmux-pane

Run a command in a temporary tmux pane that has the user's full interactive zsh environment.
The pane opens, runs the command, captures output, and closes automatically.

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
2. Runs the command inside `zsh -ic` (interactive login shell)
3. Waits for the pane to close
4. Returns captured stdout with ANSI escape codes stripped
5. Exits with the command's exit code

## Output behavior

- If the command succeeds and output exceeds 20 lines, only the last 20 lines are shown
  (with a truncation notice)
- If the command fails, the full output is returned
- ANSI escape sequences are stripped from the output

## Examples

```bash
# Run a CLI tool that needs shims/PATH — no quotes needed
run-in-tmux-pane mise doctor

# Ask Claude a question — inner quotes require outer single quotes
run-in-tmux-pane 'claude --print "Explain this error: undefined method foo"'

# Run a command that needs shell aliases — no quotes needed
run-in-tmux-pane gdk start rails
```

## Limitations

- Requires an active tmux session (`$TMUX` must be set)
- Cannot interact with the command after launch (no stdin) — use only for commands that
  run to completion on their own
- The command runs in the user's home directory by default (zsh -ic behavior)
