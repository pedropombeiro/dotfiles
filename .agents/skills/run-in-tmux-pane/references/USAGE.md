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

- Use the normal Bash tool first when the command should work in a non-interactive shell
- Switch to `run-in-tmux-pane` when the command needs zsh functions, shell init, login environment, TTY, or interactive-shell-only auth/env state
- If a normal Bash run fails because the command is missing, the environment is incomplete, or a TTY is required, retry with tmux rather than inventing workarounds
