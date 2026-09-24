# Usage Reference

Use this reference for quoting, temporary files, and command examples. Follow
[the skill](../SKILL.md) for execution decisions, output behavior, and timeouts.

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

## GitLab Examples

Set both timeouts according to [the skill's command table](../SKILL.md#set-both-timeouts).
For repository-specific functions, select the checkout inside the command:

```bash
run-in-tmux-pane 'cd /path/to/repo && gpsup'
run-in-tmux-pane 'cd /path/to/repo && gpf'
```

Use `fgdku` for GDK updates and `test_mr` for branch-derived spec runs. Their
project workflows live in the GDK and MR workflow skills under
`~/.config/dotfiles/gitlab/.opencode/skills/`.
