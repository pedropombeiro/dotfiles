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

Do NOT use `--no-pager` with `git` or `yadm`. The pager does not activate in
non-interactive shells, so the flag is unnecessary and breaks yadm commands.

When running `git rebase --continue` or any git/yadm command that opens an
editor, prefix with `GIT_EDITOR=true` to prevent the editor from blocking
(the non-interactive shell will SIGTERM nvim, causing a timeout).

### File Organization

- **Alternate files**: Use suffixes for platform-specific configs
  - `##distro.qts` - QNAP QTS
  - `##os.Darwin` - macOS
  - `##os.Linux` - Linux
  - `##class.Work` - Work machines
  - Combined: `##os.Darwin,class.Work`
- **Agent docs**: `~/.agents/docs/` - Documentation for agents
- **Bootstrap**: `~/.config/yadm/bootstrap.d/` - Setup scripts (000-999 numbering)

### Important: Symlinks

YADM automatically creates symlinks for alternate files (e.g., `foo.sh` -> `foo.sh##os.Darwin`).
**Never commit these symlinks** - only commit the actual files with `##` suffixes.

**Alternate files are not additive.** Only the best-matching file is symlinked. For example, if
both `foo.sh##os.Darwin` and `foo.sh##class.Work` exist, YADM will link only the best match for
the current system. Each alternate file must be self-contained and not depend on other alternates
being present. Do not split shared content across alternates expecting a merge or fallback; copy
the full shared content into each alternate that needs it.

Example:

```text
~/.config/sesh/sesh.toml##default
~/.config/sesh/sesh.toml##distro.qts
```

On QTS, only `sesh.toml##distro.qts` is linked to `~/.config/sesh/sesh.toml`. The default file is
ignored, so the QTS variant must include all shared config plus any QTS-specific overrides.

When renaming or adding files:

1. Only use `yadm mv` or `yadm add` on files with `##` suffixes (the actual tracked files)
2. Verify with `yadm status` that only `##` files are staged, not bare symlinks
3. If symlinks appear in staging, use `yadm reset HEAD <symlink>` to unstage them

### Workflow

1. Use `yadm ls-files` to find relevant files quickly
2. Use `yadm grep` to search content instead of grep/ripgrep
3. Edit files preserving alternate file naming conventions
4. Validate with `yadm enter pre-commit run --all-files` before committing
5. Commit with clear, descriptive messages

## Conventional Commits

Use **scoped conventional commits** to organize changes logically.
This improves clarity and makes history easier to navigate.

### Format

```
<type>(<scope>): <subject>

<body>
```

### Rules

- **Type**: One of `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `style`, `perf`
- **Scope**: The area affected (e.g., `llm`, `mise`, `nvim`, `shell`, `pre-commit`)
- **Subject**: Concise description of the change
- **Grouped commits**: Separate logical changes into distinct commits rather than combining unrelated changes

### Enforcement

Commit messages are validated by **commitlint** via a `commit-msg` pre-commit
hook (see `.commitlintrc.json` for the allowed types and scopes). The hook runs
automatically on `yadm commit`; to bypass in rare cases use `--no-verify`.

### Examples

- `docs(claude): add path resolution edge case documentation`
- `chore(mise): add API key and token redactions`
- `feat(shell): add new zinit plugin configuration`
- `fix(nvim): resolve treesitter syntax highlighting issue`

### Grouping Strategy

When making multiple changes:

1. Group related files by scope and type
2. Create separate commits for different concerns (docs vs config vs features)
3. Use descriptive bodies for complex changes
4. Keep each commit focused and reviewable

## Creating Merge Requests (GitLab.com remotes)

When the remote points to `gitlab.com`, **always use `gpsup`** to push the branch and
create the MR. It automatically applies the current milestone, issue labels, and team
labels via GitLab push options — do not use `glab mr create` or manual push options.

### How to run `gpsup`

`gpsup` is implemented as a Ruby script invoked via `mise`. Run it directly:

```bash
SCRIPT_DIR="$HOME/.shellrc/zshrc.d/functions/scripts"
remote=origin
branch="$(git rev-parse --abbrev-ref HEAD)"
issue_iid="$(echo "$branch" | sed -E 's|[^0-9]+([0-9]+).*|\1|')"

mise x ruby -- ruby -r "$SCRIPT_DIR/gitlab-helpers.rb" -e "gpsup('$remote', '$issue_iid')"
```

To pass extra `git push` arguments (e.g., `--force-with-lease`), append them after `--`:

```bash
mise x ruby -- ruby -r "$SCRIPT_DIR/gitlab-helpers.rb" -e "gpsup('$remote', '$issue_iid')" -- --force-with-lease
```

After `gpsup` creates the MR, open it and **fill in the MR description** using the
project's default template (`.gitlab/merge_request_templates/`).

## Commit/Push Behavior

When committing/pushing code, first attempt without output (e.g., `git push > /dev/null 2>&1`) to minimize token usage.
Only display output if the operation fails and diagnostics are needed.
