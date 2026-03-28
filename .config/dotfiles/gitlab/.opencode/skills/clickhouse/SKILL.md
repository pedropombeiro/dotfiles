---
name: clickhouse
description: Inspect GitLab local ClickHouse tables, schemas, ingestion paths, and data patterns. Use for CH table questions, DESCRIBE TABLE, schema/source-of-truth checks under db/click_house, ClickHouse ingestion debugging, and investigating aggregates, distributions, or anomalous data in the GitLab repo.
license: MIT
compatibility: opencode
allowed-tools: Bash(.opencode/skills/clickhouse/scripts/gdk-clickhouse:*)
metadata:
  audience: developers
  workflow: database
---

# ClickHouse Development Skill

Connect to the local development ClickHouse database to inspect schemas or run queries.

Use the bundled wrapper script so connection details stay centralized.

## Bundled script paths

- When executing from the repo root, use `.opencode/skills/clickhouse/scripts/gdk-clickhouse`.
- When executing from this skill's base directory, `scripts/gdk-clickhouse` is equivalent.
- Do not assume bundled scripts are on `PATH`.

## User selection

- Use `CLICKHOUSE_USER=default` for local read-only inspection in this GitLab development setup.
- Use `CLICKHOUSE_USER=gitlab` when reproducing application-level access patterns or debugging credentials.
- Pass the `gitlab` user password via `CLICKHOUSE_GDK_GITLAB_USER_PASSWORD`; the wrapper exports `CLICKHOUSE_PASSWORD` automatically when needed.

## Decision Rule

- If the user asks for the columns or schema of a known ClickHouse table, run `DESCRIBE TABLE <table_name>` first.
- If the user asks about data patterns, distributions, aggregates, outliers, or anomalies in ClickHouse data, query the live table directly before searching the repo.
- If the user asks for the repo-defined schema, migrations, or source of truth, inspect the specific SQL definition under `db/click_house/` after or instead of the live table query.
- If the user asks how data gets into the table, inspect the matching ingestion service after identifying the table schema.
- Avoid broad `Grep` or `Glob` searches when the table name is already known.

## Connect

```bash
.opencode/skills/clickhouse/scripts/gdk-clickhouse

# Application-like access
CLICKHOUSE_USER=gitlab .opencode/skills/clickhouse/scripts/gdk-clickhouse
```

## Agent-friendly options

- Prefer the bundled `.opencode/skills/clickhouse/scripts/gdk-clickhouse` wrapper over spelling out `mise x clickhouse ...` directly.
- Prefer `FORMAT TSV` for query output the agent needs to read or compare.
- Keep using direct `--query` commands instead of interactive sessions for one-off inspection.
- Prefer schema inspection and read-only queries by default.

## Examples

```bash
# Run a single command
.opencode/skills/clickhouse/scripts/gdk-clickhouse --query "SHOW DATABASES FORMAT TSV"

# List databases
SHOW DATABASES;

# List tables in the dev database
SHOW TABLES;

# Describe a table
DESCRIBE TABLE <table_name>;

# Describe a table with machine-friendly output
.opencode/skills/clickhouse/scripts/gdk-clickhouse --query "DESCRIBE TABLE <table_name> FORMAT TSV"
```

## Agent Guidelines

1. **Use the bundled wrapper script** - Prefer `.opencode/skills/clickhouse/scripts/gdk-clickhouse` from the repo root so connection details stay centralized.
2. **Choose the user intentionally** - Use `CLICKHOUSE_USER=default` for quick local inspection, or `CLICKHOUSE_USER=gitlab` with `CLICKHOUSE_GDK_GITLAB_USER_PASSWORD` when reproducing application-like access.
3. **Prefer `FORMAT TSV` for agent-readable output** - Use compact tab-separated output when the result is meant to be parsed or compared.
4. **Read-only by default** - Prefer schema inspection and SELECT queries.
5. **Be explicit about database** - Use `gitlab_clickhouse_development` unless instructed otherwise.
6. **Prefer direct schema inspection** - Use `DESCRIBE TABLE <table_name>` before repo-wide search for known tables.

## Recommended Workflow

### Known table schema question

```bash
.opencode/skills/clickhouse/scripts/gdk-clickhouse --query "DESCRIBE TABLE <table_name> FORMAT TSV"
```

### Repo schema source of truth

- Read the matching file in `db/click_house/`.
- Use targeted file reads or targeted tracked-file search when the exact file is not obvious.

### Ingestion question

- Confirm the table schema first.
- Then inspect the matching ingestion or sync service in `app/services/` or the relevant ClickHouse ingestion path.
