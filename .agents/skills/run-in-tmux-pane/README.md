# run-in-tmux-pane

An [opencode](https://opencode.ai) skill that runs commands in a temporary tmux
pane with the user's full interactive zsh environment, captures the output, and
returns it to the agent.

## Problems it solves

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

## How it works

1. Opens a tmux split-pane (30% height, detached) running `zsh -ilc`
2. Executes the command inside the user's full interactive login shell
3. Captures stdout and stderr via `tee` to a temp file
4. Polls until the pane exits, then returns the output with ANSI escapes stripped
5. Truncates successful output to 20 lines; returns full output on failure
6. Exits with the command's original exit code

## Requirements

- macOS or Linux
- tmux (the agent session must be running inside a tmux session)
- zsh

## Installation

Install via the opencode skill registry, or clone manually:

```bash
# Symlink the script onto your PATH
ln -s /path/to/skills/run-in-tmux-pane/scripts/run-in-tmux-pane ~/.local/bin/run-in-tmux-pane
```

## Usage

```bash
# Simple command — pass arguments directly
run-in-tmux-pane mise doctor

# Command with inner quotes — wrap in single quotes
run-in-tmux-pane 'claude -p "Explain this error"'
```

See [SKILL.md](SKILL.md) for the full quoting rules and agent-facing
documentation.

## Decision rule

- Use normal Bash first for standard non-interactive executables.
- Use `run-in-tmux-pane` immediately for zsh functions, TTY-dependent tools, and commands that rely on login-shell state.
- If Bash fails due to missing command, missing shell init, or TTY requirements, retry once with `run-in-tmux-pane`.

Common GitLab examples:

- `run-in-tmux-pane fgdku`
- `run-in-tmux-pane gpsup`
- `run-in-tmux-pane test_mr`

## Configuration

| Variable               | Default | Description                                                                                        |
| ---------------------- | ------- | -------------------------------------------------------------------------------------------------- |
| `TMUX_PANE_LINGER`     | `3`     | Seconds to keep the tmux pane visible after the command finishes. Set to `0` to close immediately. |
| `TMUX_PANE_TAIL_LINES` | `20`    | Number of trailing lines to keep when truncating successful output.                                |
| `TMUX_PANE_TIMEOUT`    | `300`   | Maximum seconds to wait for the command to finish before killing the pane (exits with code 124).   |

> **Set the Bash tool timeout higher than `TMUX_PANE_TIMEOUT`.** Use the formula
> `bash_timeout_ms = (TMUX_PANE_TIMEOUT + 60) * 1000`. With the default
> `TMUX_PANE_TIMEOUT=300`, pass at least `360000`. If the Bash tool times out
> first, the script is killed and its pane is torn down by the `cleanup` trap.

## Security considerations

This skill runs commands inside `zsh -ilc`, which loads the user's full
interactive shell environment (aliases, ssh-agent, GPG keys, etc.). This is
by design — it solves the problem of agent tools running in a minimal
non-interactive shell.

The agent framework's permission model controls which commands the agent may
run. Grant access only to specific commands rather than a blanket allow:

```json
{
  "bash": {
    "run-in-tmux-pane gpsup": "allow",
    "run-in-tmux-pane fgdku": "allow",
    "run-in-tmux-pane *": "deny"
  }
}
```

This ensures the agent can only invoke the exact commands you approve, even
though each command runs in a fully interactive shell.

## License

MIT
