# Beads (bd) Issue Tracker

## Overview

[Beads](https://github.com/steveyegge/beads) (`bd`) is used for lightweight issue tracking
with dependency support. Installed via mise.

## Database

- Backend: **Dolt** (SQL-based version control)
- Database name: **`dotfiles`** (user-agnostic, matches the issue prefix)
- Config: `~/.beads/metadata.json` (YADM-tracked) stores `dolt_database`
- Data: `~/.beads/dolt/dotfiles/` (gitignored, synced via Dolt remotes)

## Cross-Machine Sync

The Dolt database is synced between machines using a **filesystem-based Dolt remote**
stored in Syncthing:

```
Remote path: ~/Sync/pedro/.beads-dolt-remote/dotfiles
```

The absolute path differs per machine, so each machine has its own `origin` remote
pointing to its local Syncthing path.

### Sync workflow

- **Push** (after making changes): `bd dolt commit -m "message" && bd dolt push`
- **Pull** (to get changes from another machine): `bd dolt pull`

### Setting up a new machine

1. Pull YADM dotfiles (`yadm pull`) to get `~/.beads/metadata.json` and config
2. Wait for Syncthing to sync `~/Sync/pedro/.beads-dolt-remote/dotfiles/`
3. Initialize bd:
   ```bash
   bd init --prefix dotfiles --database dotfiles --skip-agents --skip-hooks
   ```
4. Add the Dolt remote (adjust the absolute path for the machine):
   ```bash
   bd dolt remote add origin "file://<absolute-path>/Sync/pedro/.beads-dolt-remote/dotfiles"
   ```
5. Pull the database:
   ```bash
   bd dolt pull
   ```

## YADM-Tracked Files

These files under `~/.beads/` are tracked by YADM:

- `metadata.json` — database name, backend, project ID
- `config.yaml` — issue prefix, backup settings
- `hooks/` — git hooks for bd integration
- `.gitignore` — keeps runtime/data files out of YADM
- `README.md`

Everything else (the Dolt data directory, server PID/logs, backups) is gitignored.

## Important

- The database was originally named `pedro` (derived from `$USER` at init time).
  It was renamed to `dotfiles` to avoid failures on machines with a different username.
- The `dolt/` directory is **not** synced via YADM — only via the Dolt remote in Syncthing.
