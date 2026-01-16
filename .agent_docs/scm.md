# Source Control Management

## YADM (Dotfiles)

Git commands on the `~` directory are managed through `yadm` instead of `git`.

- Use `yadm` commands instead of `git` for version control in the home directory
- For commands needing git context (e.g., `pre-commit run`), prefix with `yadm enter`

## Commit/Push Behavior

When committing/pushing code, first attempt without output (e.g., `git push > /dev/null 2>&1`) to minimize token usage. Only display output if the operation fails and diagnostics are needed.
