---
name: psql
description: >-
  Inspect local GDK PostgreSQL test and development
  databases with gdk psql. Use for Postgres schema checks, table and index
  inspection, read-only SQL queries, migration verification, and investigating
  GitLab data in local test or dev databases.
license: MIT
compatibility: opencode
metadata:
  audience: developers
  author: pedropombeiro
  keywords: postgres, psql, schema, indexes, sql, gdk
  workflow: database
---

# PostgreSQL Development Skill

Use `gdk psql` to connect to local GDK PostgreSQL databases for schema inspection or queries.
Prefer the **test** databases to avoid corrupting development data.

## Databases

| Database | Name | Use when |
|---|---|---|
| Test CI (default) | `gitlabhq_test_ci` | CI-related tables (`ci_*`). Preferred by default. |
| Test | `gitlabhq_test` | Non-CI tables. |
| Development CI | `gitlabhq_development_ci` | Need CI data or must test against real seed data. |
| Development | `gitlabhq_development` | Need non-CI data or must test against real seed data. |

## Connect

```bash
# Default (test CI)
gdk psql -X -d gitlabhq_test_ci

# Test (non-CI)
gdk psql -X -d gitlabhq_test

# Development CI (only when needed)
gdk psql -X -d gitlabhq_development_ci

# Development (only when needed)
gdk psql -X -d gitlabhq_development
```

## Agent-friendly options

- Use `-X` to ignore `~/.psqlrc` so formatting and behavior stay predictable.
- Use `-P pager=off` for non-interactive commands so output never pages.
- Use `-A -F $'\t' -t` when the agent needs raw values instead of formatted tables.
- Use `-v ON_ERROR_STOP=1` for multi-statement commands so failures stop immediately.

## Examples

```bash
# Run a single query
gdk psql -X -d gitlabhq_test_ci -P pager=off -c "SELECT version();"

# List tables matching a pattern
gdk psql -X -d gitlabhq_test_ci -P pager=off -c "\dt *ci_runner*"

# Describe a table
gdk psql -X -d gitlabhq_test_ci -P pager=off -c "\d+ ci_runner_machines"

# List indexes on a table
gdk psql -X -d gitlabhq_test_ci -P pager=off -c "SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'ci_runner_machines' ORDER BY indexname;"

# Return raw values in a machine-friendly format
gdk psql -X -d gitlabhq_test_ci -P pager=off -A -F $'\t' -t -c "SELECT id, status FROM p_ci_builds LIMIT 5;"

# Check partitioned index attachments
gdk psql -X -v ON_ERROR_STOP=1 -d gitlabhq_test_ci -P pager=off -c "
SELECT
  parent_idx.relname AS parent_index,
  child_idx.relname AS attached_index,
  child_tbl.relname AS partition_table
FROM pg_inherits idx_inh
JOIN pg_class parent_idx ON idx_inh.inhparent = parent_idx.oid
JOIN pg_class child_idx ON idx_inh.inhrelid = child_idx.oid
JOIN pg_index pi ON child_idx.oid = pi.indexrelid
JOIN pg_class child_tbl ON pi.indrelid = child_tbl.oid
WHERE parent_idx.relname = '<parent_index_name>'
ORDER BY child_tbl.relname;
"
```

## Agent Guidelines

1. **Use `gdk psql`** - Prefer `gdk psql` over raw `psql` so connection details and ports stay implicit.
2. **Prefer test databases** - Use `gitlabhq_test_ci` (default) or `gitlabhq_test`. Only use development databases when explicitly asked or when seed data is needed.
3. **Read-only by default** - Prefer `SELECT`, `\d`, `\dt`, and other inspection commands. Only run DDL/DML when explicitly asked.
4. **Use `-X` and `-P pager=off`** - Keep formatting predictable and avoid pager output in non-interactive use.
5. **Use `-c` for single queries** - Pass queries via `-c` flag rather than interactive mode.
6. **Use `-A -F $'\t' -t` for raw values** - Prefer compact output when the agent needs data rather than presentation.
7. **Stop on error** - When running multiple statements, start with `\set ON_ERROR_STOP on` or pass `-v ON_ERROR_STOP=1` on the command line.
8. **Partitioned tables** - Many CI tables are partitioned. Parent indexes (`ON ONLY`) may differ from partition-level indexes. Always check both levels when investigating index issues.
9. **Schema reference** - The expected schema is defined in `db/structure.sql` (non-CI) and `db/ci_structure.sql` (CI).
