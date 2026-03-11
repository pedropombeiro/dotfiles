---
name: gdk
description: GDK update, secrets, and branch management helpers
license: MIT
compatibility: opencode
metadata:
  audience: developers
  workflow: gitlab
---

# GDK Skill

Shell functions for managing the GitLab Development Kit: full update orchestration,
switching to main branch cleanly, and setting up API tokens from 1Password.

All functions are zsh functions loaded from `~/.shellrc/zshrc.d/functions/`.

## Available Commands

### `fgdku`

Comprehensive GDK update orchestrator. Performs the full update cycle:

1. Restores `bin/rake`, `bin/rspec`, `bin/rails`, `bin/spring`, `db/structure.sql`, `package.json`
2. Prompts to reset if there are uncommitted changes
3. Resets network adapter if network is unreachable
4. Installs mise tools and ensures the `gdk` gem is available
5. Stops Spring, restarts PostgreSQL, runs `gdk update`
6. Reinstalls bundle and regenerates Spring binstubs
7. Runs a simple rspec test to bring up Gitaly
8. Runs pending ClickHouse migrations
9. Prunes stale local branches and rebases all remaining branches
10. Switches back to the original branch
11. Runs `gdk cleanup`, truncates large logs, restarts GDK
12. Enables db sandbox, regenerates schema if branch migrations exist
13. Warms up Rails environment

```bash
fgdku
```

Reports progress via iTerm2 badges and Home Assistant webhooks.

### `gswm`

Switches to the main branch, restoring `db/` and `package.json` first and
resetting the GDK sandbox if inside a GDK directory.

```bash
gswm
```

### `setup_gitlab_secrets`

Fetches `GITLAB_TOKEN`, `GITLAB_STAGING_TOKEN`, and `GITLAB_GDK_TOKEN` from
1Password and exports them as environment variables.

```bash
setup_gitlab_secrets
```

Requires 1Password CLI (`op`) and a `gitlab` account configured.

## Agent Guidelines

1. **`fgdku` is interactive and long-running** — it prompts on uncommitted changes; do not run from an agent without user confirmation
2. **Use `gswm`** when the user wants to return to main branch cleanly (safer than plain `git switch`)
3. **`setup_gitlab_secrets` requires biometric auth** — cannot be run non-interactively
4. **GDK_ROOT must be set** — `gswm` and `fgdku` check `$GDK_ROOT` to determine if they're in a GDK directory
