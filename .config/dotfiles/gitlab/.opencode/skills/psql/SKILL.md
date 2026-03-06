---
name: psql
description: Connect to local Postgres test/dev databases
license: MIT
compatibility: opencode
metadata:
  audience: developers
  workflow: database
---

# PostgreSQL Development Skill

Connect to local GDK PostgreSQL databases to inspect schemas or run queries.
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
psql -h localhost -p 5432 -d gitlabhq_test_ci

# Test (non-CI)
psql -h localhost -p 5432 -d gitlabhq_test

# Development CI (only when needed)
psql -h localhost -p 5432 -d gitlabhq_development_ci

# Development (only when needed)
psql -h localhost -p 5432 -d gitlabhq_development
```

## Examples

```bash
# Run a single query
psql -h localhost -p 5432 -d gitlabhq_test_ci -c "SELECT version();"

# List tables matching a pattern
psql -h localhost -p 5432 -d gitlabhq_test_ci -c "\dt *ci_runner*"

# Describe a table
psql -h localhost -p 5432 -d gitlabhq_test_ci -c "\d+ ci_runner_machines"

# List indexes on a table
psql -h localhost -p 5432 -d gitlabhq_test_ci -c "SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'ci_runner_machines' ORDER BY indexname;"

# Check partitioned index attachments
psql -h localhost -p 5432 -d gitlabhq_test_ci -c "
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

1. **Prefer test databases** - Use `gitlabhq_test_ci` (default) or `gitlabhq_test`. Only use development databases when explicitly asked or when seed data is needed.
2. **Read-only by default** - Prefer `SELECT`, `\d`, `\dt`, and other inspection commands. Only run DDL/DML when explicitly asked.
3. **Use `-c` for single queries** - Pass queries via `-c` flag rather than interactive mode.
4. **Stop on error** - When running multiple statements, start with `\set ON_ERROR_STOP on` or pass `-v ON_ERROR_STOP=1` on the command line.
5. **Partitioned tables** - Many CI tables are partitioned. Parent indexes (`ON ONLY`) may differ from partition-level indexes. Always check both levels when investigating index issues.
6. **Schema reference** - The expected schema is defined in `db/structure.sql` (non-CI) and `db/ci_structure.sql` (CI).
