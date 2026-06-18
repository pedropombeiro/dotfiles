---
name: run-in-tmux-pane
description: "Run commands in a temporary tmux pane with full interactive zsh environment (login shell, shims, PATH, aliases, TTY)."
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
- A command depends on environment variables or auth state that are present only in the interactive shell
- The command is a zsh function such as `fgdku`, `gpsup`, or `test_mr`

## When not to use

- For simple non-interactive commands that work fine with the normal Bash tool
- When you only need to read or edit files; use the dedicated file tools instead
- When the command requires live stdin interaction after launch; the pane is not interactive once started

## Setup

The script is bundled at [scripts/run-in-tmux-pane](scripts/run-in-tmux-pane).
To make it available system-wide, symlink it onto your PATH:

```bash
ln -s "$(pwd)/scripts/run-in-tmux-pane" ~/.local/bin/run-in-tmux-pane
```

## Usage

See `references/USAGE.md` for quoting rules, temp-file conventions, and examples.

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

See `references/USAGE.md` for concrete examples.

## Configuration

| Variable | Default | Description |
|---|---|---|
| `TMUX_PANE_LINGER` | `3` | Seconds to keep the tmux pane visible after the command finishes. Set to `0` to close immediately. |
| `TMUX_PANE_TAIL_LINES` | `20` | Number of trailing lines to keep when truncating successful output. |
| `TMUX_PANE_TIMEOUT` | `300` | Maximum seconds to wait for the command to finish before killing the pane (exits with code 124). |

## Important: Bash tool timeout must exceed `TMUX_PANE_TIMEOUT`

Always set the Bash tool's `timeout` parameter **higher** than `TMUX_PANE_TIMEOUT`
(e.g. `timeout: 360000` for the default `TMUX_PANE_TIMEOUT=300`). If the Bash tool times out
before the tmux pane finishes, you get partial output with no exit code — and the
tmux command is still running in the background. This can be mistaken for a
completed run, leading to unnecessary retries or incorrect assumptions about the
command's result.

## Decision Rule

Use this decision order:

1. Start with the normal Bash tool when the command should work in a non-interactive shell.
2. Use `run-in-tmux-pane` immediately when the command is a zsh function, requires a TTY, or is
   known to depend on login-shell state.
3. If a normal Bash run fails because the command is missing, auth state is absent, shell init was
   skipped, or a TTY is required, retry once with `run-in-tmux-pane`.
4. Do not invent shell workarounds when tmux is the correct execution path.

See `references/USAGE.md` for the Bash-vs-tmux checklist and GitLab-specific examples.

## Limitations

- Requires an active tmux session (`$TMUX` must be set)
- Cannot interact with the command after launch (no stdin) — use only for commands that
  run to completion on their own
- The command runs in the user's home directory by default (zsh -ilc behavior)
