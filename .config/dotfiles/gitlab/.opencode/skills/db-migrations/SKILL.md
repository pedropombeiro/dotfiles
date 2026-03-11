---
name: db-migrations
description: List and undo branch-specific database migrations
license: MIT
compatibility: opencode
metadata:
  audience: developers
  workflow: database
---

# Database Migrations Skill

Shell functions for managing branch-specific database migrations in the GitLab project:
listing which migrations were added in the current branch and rolling them back.

All functions are zsh functions loaded from `~/.shellrc/zshrc.d/functions/`.

## Available Commands

### `list_migrations`

Lists migration versions added in the current branch (files in `db/schema_migrations/`
that don't exist on the main branch), sorted in reverse chronological order.

```bash
list_migrations
# Example output:
# 20260310120000
# 20260309150000
```

### `undo_migrations`

Rolls back all branch-specific migrations on both `main` and `ci` databases.
Only runs when the current directory is inside `$GDK_ROOT`.

```bash
undo_migrations
```

For each migration returned by `list_migrations`, runs:
```
bin/rails db:migrate:down:main VERSION=<version>
bin/rails db:migrate:down:ci VERSION=<version>
```

Starts PostgreSQL via `gdk start postgresql` before rolling back.

## Agent Guidelines

1. **Use `list_migrations`** to check what migrations exist on the current branch before switching branches
2. **Run `undo_migrations` before switching branches** if the branch has migrations — prevents schema inconsistencies
3. **Must be in GDK directory** — `undo_migrations` checks `$GDK_ROOT` and exits early otherwise
4. **Both functions require zsh** — invoke via `zsh -c 'source ~/.zshrc && <function>'` if needed
5. **Complements the `psql` skill** — use `psql` skill for inspecting schema, this skill for managing migrations
