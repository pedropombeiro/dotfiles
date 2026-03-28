# Usage Reference

Use this reference when you need quoting details, temporary-file conventions, or the decision boundary between normal Bash and tmux.

## Quoting Rule

Only wrap the command in single quotes when it contains inner quotes or special shell characters (`"`, `'`, `$`, `` ` ``, `\`). For simple commands with no special characters, pass arguments directly.

```bash
# Simple command
run-in-tmux-pane mise doctor

# Command with inner quotes
run-in-tmux-pane 'claude -p "Hello, how are you?"'
```

## Temporary Files

- Use `$TMPDIR` for helper scripts and temporary files
- Do not hardcode `/tmp` or guess a machine-specific temp directory
- Clean up temporary scripts after the command completes

```bash
run-in-tmux-pane 'python3 "$TMPDIR/my-script.py"'
rm -f "$TMPDIR/my-script.py"
```

## Output Behavior

- Successful commands are truncated to the last configured lines when output is long
- Failed commands return full output
- ANSI escape sequences are stripped from captured output

## Decision Rule

- Use the normal Bash tool first when the command should work in a non-interactive shell.
- Use `run-in-tmux-pane` immediately for zsh functions, commands needing a TTY, or commands known to depend on shell init or interactive auth state.
- If a normal Bash run fails because the command is missing, the environment is incomplete, or a TTY is required, retry with tmux rather than inventing workarounds.

## Quick Checklist

Use `run-in-tmux-pane` when any of these are true:

- The command is a zsh function or alias.
- The command needs `zsh -ilc` behavior.
- The command needs interactive auth or environment setup already present in the shell.
- The command refuses to run without a TTY.

Stay with normal Bash when all of these are true:

- The command is a standard executable.
- It is non-interactive.
- It does not depend on shell startup files.
- A normal Bash timeout is sufficient.

## Timeout Rule

- Set the Bash tool timeout higher than `TMUX_PANE_TIMEOUT`.
- Recommended formula: `bash_timeout_ms = (TMUX_PANE_TIMEOUT + 60) * 1000`.
- With the skill default `TMUX_PANE_TIMEOUT=300`, use at least `360000`.
- For known long-running GitLab commands, prefer larger fixed values instead of the minimum.

## GitLab Examples

- Use `run-in-tmux-pane fgdku` for GDK updates. Use a Bash timeout of at least `1800000`.
- Use `run-in-tmux-pane gpsup` for GitLab MR creation when the helper is a zsh function.
- Use `run-in-tmux-pane test_mr` for branch-derived spec runs. Use a Bash timeout of at least `600000`.
- Keep normal Bash for commands like `git status`, `git diff`, and targeted `bundle exec rspec <file>` when they do not need zsh shell state.
