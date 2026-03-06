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

## Connect

```bash
mise x clickhouse -- clickhouse client --port 9001 -d gitlab_clickhouse_development -u default
```

## Examples

```bash
# Run a single command
mise x clickhouse -- clickhouse client --port 9001 -d gitlab_clickhouse_development -u default --query "SHOW DATABASES"

# List databases
SHOW DATABASES;

# List tables in the dev database
SHOW TABLES;

# Describe a table
DESCRIBE TABLE <table_name>;
```

## Agent Guidelines

1. **Use the mise client command** - Connect using the exact command above
2. **Read-only by default** - Prefer schema inspection and SELECT queries
3. **Be explicit about database** - Use `gitlab_clickhouse_development` unless instructed otherwise
