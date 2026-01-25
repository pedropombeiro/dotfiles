# Source Control Management

## YADM (Dotfiles)

Git commands on the `~` directory are managed through `yadm` instead of `git`.

- Use `yadm` commands instead of `git` for version control in the home directory
- For commands needing git context (e.g., `pre-commit run`), prefix with `yadm enter`

### Key Commands

| Command                     | Purpose                                 |
| --------------------------- | --------------------------------------- |
| `yadm ls-files`             | List all tracked dotfiles (fast search) |
| `yadm grep <pattern>`       | Search content within tracked dotfiles  |
| `yadm status` / `yadm diff` | Check changes                           |
| `yadm enter <cmd>`          | Run commands needing git context        |

### File Organization

- **Alternate files**: Use suffixes for platform-specific configs
  - `##distro.qts` - QNAP QTS
  - `##os.Darwin` - macOS
  - `##os.Linux` - Linux
  - `##class.Work` - Work machines
  - Combined: `##os.Darwin,class.Work`
- **Agent docs**: `~/.agent_docs/` - Documentation for agents
- **Bootstrap**: `~/.config/yadm/bootstrap.d/` - Setup scripts

### Workflow

1. Use `yadm ls-files` to find relevant files quickly
2. Use `yadm grep` to search content instead of grep/ripgrep
3. Edit files preserving alternate file naming conventions
4. Validate with `yadm enter pre-commit run --all-files` before committing
5. Commit with clear, descriptive messages

## Commit/Push Behavior

When committing/pushing code, first attempt without output (e.g., `git push > /dev/null 2>&1`) to minimize token usage. Only display output if the operation fails and diagnostics are needed.
