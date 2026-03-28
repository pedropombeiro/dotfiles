---
name: clickhouse
description: Connect to local ClickHouse dev database
license: MIT
compatibility: opencode
metadata:
  audience: developers
  workflow: database
---

# ClickHouse Development Skill

Connect to the local development ClickHouse database to inspect schemas or run queries.

## User selection

- Use `-u default` for local read-only inspection in this GitLab development setup.
- Use `-u gitlab` when reproducing application-level access patterns or debugging credentials.
- Pass the `gitlab` user password via `CLICKHOUSE_GDK_GITLAB_USER_PASSWORD`; do not hardcode or persist the secret in skill docs or commands.

## Decision Rule

- If the user asks for the columns or schema of a known ClickHouse table, run `DESCRIBE TABLE <table_name>` first.
- If the user asks for the repo-defined schema, migrations, or source of truth, inspect the specific SQL definition under `db/click_house/` after or instead of the live table query.
- If the user asks how data gets into the table, inspect the matching ingestion service after identifying the table schema.
- Avoid broad `Grep` or `Glob` searches when the table name is already known.

## Connect

```bash
mise x clickhouse -- clickhouse client --port 9001 -d gitlab_clickhouse_development -u default

# Application-like access
CLICKHOUSE_PASSWORD="$CLICKHOUSE_GDK_GITLAB_USER_PASSWORD" mise x clickhouse -- clickhouse client --port 9001 -d gitlab_clickhouse_development -u gitlab
```

## Agent-friendly options

- Prefer `FORMAT TSV` for query output the agent needs to read or compare.
- Keep using direct `--query` commands instead of interactive sessions for one-off inspection.
- Prefer schema inspection and read-only queries by default.

## Examples

```bash
# Run a single command
mise x clickhouse -- clickhouse client --port 9001 -d gitlab_clickhouse_development -u default --query "SHOW DATABASES FORMAT TSV"

# List databases
SHOW DATABASES;

# List tables in the dev database
SHOW TABLES;

# Describe a table
DESCRIBE TABLE <table_name>;

# Describe a table with machine-friendly output
mise x clickhouse -- clickhouse client --port 9001 -d gitlab_clickhouse_development -u default --query "DESCRIBE TABLE <table_name> FORMAT TSV"
```

## Agent Guidelines

1. **Use the mise client command** - Connect using the exact command above.
2. **Choose the user intentionally** - Use `-u default` for quick local inspection, or `-u gitlab` with `CLICKHOUSE_GDK_GITLAB_USER_PASSWORD` when reproducing application-like access.
3. **Prefer `FORMAT TSV` for agent-readable output** - Use compact tab-separated output when the result is meant to be parsed or compared.
4. **Read-only by default** - Prefer schema inspection and SELECT queries.
5. **Be explicit about database** - Use `gitlab_clickhouse_development` unless instructed otherwise.
6. **Prefer direct schema inspection** - Use `DESCRIBE TABLE <table_name>` before repo-wide search for known tables.

## Recommended Workflow

### Known table schema question

```bash
mise x clickhouse -- clickhouse client --port 9001 -d gitlab_clickhouse_development -u default --query "DESCRIBE TABLE <table_name> FORMAT TSV"
```

### Repo schema source of truth

- Read the matching file in `db/click_house/`.
- Use targeted file reads or targeted tracked-file search when the exact file is not obvious.

### Ingestion question

- Confirm the table schema first.
- Then inspect the matching ingestion or sync service in `app/services/` or the relevant ClickHouse ingestion path.
