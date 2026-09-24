---
name: run-in-tmux-pane
description: "Use for commands that require an interactive shell, a TTY, or shell-only functions. Run them in a temporary tmux pane with the full zsh environment. Use the shell tool directly for ordinary non-interactive commands."
version: 1.0.0
license: MIT
compatibility: opencode
metadata:
  author: pedropombeiro
  audience: developers
---

# run-in-tmux-pane

Run a command in a temporary tmux pane using `zsh -ilc`. The helper captures
stdout and stderr, closes the pane, and returns the command's exit code.
"Shell tool" means `shell` in OpenCode or `Bash` in Claude Code.

## Choose the execution tool

1. Use the normal shell tool for commands that work non-interactively, including
   standard Git commands and targeted tests that do not depend on shell startup.
2. Use `run-in-tmux-pane` for zsh functions, commands requiring a TTY, or commands
   known to depend on login-shell environment or authentication state.
3. If the normal shell tool fails because of those requirements, retry once with
   `run-in-tmux-pane`.

Use tmux for the command that needs it. Use dedicated file tools for reads and
edits, and avoid preflight tmux calls.

## Requirements and setup

- The agent session must run inside tmux with `$TMUX` and `$TMUX_PANE` set.
- The command must finish without further input; the agent cannot send stdin
  after launch.
- Commands start in the user's home directory. Include `cd` when needed.

The helper is [scripts/run-in-tmux-pane](scripts/run-in-tmux-pane). If it is not
on `PATH`, link it from the installed skill directory to
`~/.local/bin/run-in-tmux-pane`.

## Usage

```bash
run-in-tmux-pane <command> [args...]
```

See [the usage reference](references/USAGE.md) for quoting, temporary files, and
command examples.

## Configuration and output

| Variable               | Default | Purpose                                                                        |
| ---------------------- | ------- | ------------------------------------------------------------------------------ |
| `TMUX_PANE_LINGER`     | `3`     | Seconds the pane stays visible after completion; use `0` to close immediately. |
| `TMUX_PANE_TAIL_LINES` | `20`    | Trailing lines shown for long successful output; failures return full output.  |
| `TMUX_PANE_TIMEOUT`    | `300`   | Seconds before the helper kills the pane and exits with code `124`.            |

The helper strips ANSI escape sequences from captured output.

## Set both timeouts

Set the shell tool timeout to at least `(TMUX_PANE_TIMEOUT + 60) * 1000`
milliseconds. For long commands, increase the pane timeout as well as the shell
timeout. Use these minimum budgets for the shell functions below:

| Command        | `TMUX_PANE_TIMEOUT` (seconds) | Shell `timeout` (milliseconds) |
| -------------- | ----------------------------- | ------------------------------ |
| `gpsup`, `gpf` | `300`                         | `360000`                       |
| `fgdku`        | `1740`                        | `1800000`                      |
| `test_mr`      | `540`                         | `600000`                       |

If the shell tool terminates the helper early, output can be incomplete. The
helper's termination trap attempts to kill its pane; verify the command's result
before retrying an operation with side effects.
