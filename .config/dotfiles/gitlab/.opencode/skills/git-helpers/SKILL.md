---
name: git-helpers
description: Git branch management helpers (parent branch, rebase all, force-push, diff structure)
license: MIT
compatibility: opencode
metadata:
  audience: developers
  workflow: git
---

# Git Helpers Skill

Shell functions for managing branches in the GitLab project: computing parent branches,
rebasing all local branches while preserving dependency chains, force-pushing related
branches, and extracting structure.sql diffs.

All functions are zsh functions loaded from `~/.shellrc/zshrc.d/functions/`.

## Branch Naming Convention

These tools assume branches follow the pattern:

```
<username>/<issue-id>/<branch-name>
```

For example: `pedropombeiro/573604/3-add-params-to-rest-api`

Branches sharing the same `<issue-id>` are considered related and may form dependency chains.

## Available Commands

### `git_parent`

Returns the parent branch of the current (or specified) branch by computing
branch dependencies from the issue-based naming convention.

```bash
git_parent                    # parent of current branch
git_parent some/123/branch    # parent of specific branch
```

Uses a Ruby helper (`scripts/git-helpers.rb`) to compute the dependency graph.

### `rebase_all`

Rebases all local branches matching `<username>/<id>/<name>`, preserving branch
dependency chains. Restores `db/`, `bin/` binstubs, and `package.json` before rebasing.

```bash
rebase_all
```

After rebasing, regenerates Spring binstubs if available.

### `gpif`

Force-pushes (`--force-with-lease`) all branches related to the current branch's
issue number. Restores Spring binstubs before and after.

```bash
gpif                # push all related branches
gpif --no-verify    # skip pre-push hooks
```

### `diff_structure`

Outputs only the added lines from `db/structure.sql` relative to the main branch.
Useful for copying schema changes to an SSH session on a thin clone.

```bash
diff_structure              # print to stdout
diff_structure | pbcopy     # copy to clipboard
```

## Agent Guidelines

1. **Use `git_parent`** to understand branch dependency chains before rebasing
2. **`rebase_all` modifies working tree** — it restores tracked files before rebasing; warn the user about uncommitted changes
3. **`gpif` force-pushes** — always confirm with the user before running
4. **All functions delegate to Ruby helpers** in `~/.shellrc/zshrc.d/functions/scripts/` — ensure `mise x ruby` works
5. **All functions require zsh** — invoke via `zsh -c 'source ~/.zshrc && <function>'` if needed
