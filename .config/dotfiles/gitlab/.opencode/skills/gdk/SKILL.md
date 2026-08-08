---
name: gdk
description: Handle GitLab Development Kit updates, local secrets, and GDK branch workflows. Use for fgdku-based updates, setting up GitLab secrets, managing branch-specific GDK state, and other local GitLab development environment operations.
license: MIT
compatibility: opencode
metadata:
  audience: developers
  author: pedropombeiro
  keywords: gdk, gitlab-development-kit, update, secrets, environment
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
9. Rebases all local branches, then prunes those whose tip is reachable from master
10. Switches back to the original branch
11. Runs `gdk cleanup`, truncates large logs, restarts GDK
12. Enables db sandbox, regenerates schema if branch migrations exist
13. Warms up Rails environment

```bash
run-in-tmux-pane fgdku
```

Reports progress via iTerm2 badges and Home Assistant webhooks.
Must be run via [`run-in-tmux-pane`](~/.agents/docs/tmux.md#running-commands-in-a-temporary-tmux-pane)
since it is an autoloaded zsh function and is long-running/interactive.
Set the Bash tool timeout to at least 1800000 ms (30 min).

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

## Which service owns which files

Restarting the wrong service silently serves stale config. The owning process is not always the
directory the files live in.

| Files | Restart |
|---|---|
| `gitlab-ai-gateway/duo_workflow_service/**` (flow YAML, components, routers) | `gdk restart duo-workflow-service` |
| `gitlab-ai-gateway/ai_gateway/**` (prompts, model config) | `gdk restart gitlab-ai-gateway` |
| `gitlab/**` (Rails app, API) | `gdk restart rails-web` (+ `rails-background-jobs` for workers) |

Flow configs under `duo_workflow_service/agent_platform/v1/flows/configs/` are the trap: they sit
inside the `gitlab-ai-gateway` checkout but are loaded by the **`duo-workflow-service`** process.
Restarting `gitlab-ai-gateway` leaves the old config in memory, and the only symptom is that your
change appears to have no effect.

Confirm the restart took by checking the PID actually changed:

```bash
ps aux | rg "duo.workflow" | rg -v "rg |svlogd|runsv"
```

## Troubleshooting

**Jobs stuck in `created`, never reaching `pending`.** Sidekiq wedges without logging an error and
`gdk status` still reports `rails-background-jobs` as up. Redis queues, `retry`, `dead` and
`schedule` are all empty, so nothing looks wrong. `gdk restart` clears it and stuck jobs are picked
up within seconds. Before a long eval or CI-dependent run, assert a job leaves `created` rather than
trusting `gdk status`.

**Runner offline with `403 Forbidden` on `/api/v4/jobs/request`.** Three consecutive 403s make the
runner disable itself for a full hour:

```
ERROR: Runner "…" is unhealthy and will be disabled for 1h0m0s seconds!
```

This happens when the runner polls while Rails is still booting. `gdk restart runner` clears the
penalty immediately — no need to wait it out. If 403s persist after Rails is healthy, the token
itself is invalid: check for the literal placeholder `DEFAULT TOKEN` in
`gitlab-runner-config.toml`, which some restarts write over the real token. Restore the saved
registration token and restart.

**Rails takes several minutes to boot.** After `gdk restart`, `/api/v4/version` returns 502 with a
"Waiting for GitLab to boot" page for up to ~5 minutes. Poll for a 200 rather than assuming failure.

## Agent Guidelines

1. **Never update from remote manually** — do not run `git pull`, `git fetch` + `git rebase`, or `gdk update` directly in a GDK repo. Always use `run-in-tmux-pane fgdku` instead; it handles fetching, rebasing all branches, bundle install, migrations, GDK restart, and post-update cleanup in the correct order
2. **`fgdku` is interactive and long-running** — always run via `run-in-tmux-pane fgdku`; it prompts on uncommitted changes so do not run without user confirmation
3. **Use `gswm`** when the user wants to return to main branch cleanly (safer than plain `git switch`)
4. **`setup_gitlab_secrets` requires biometric auth** — cannot be run non-interactively
5. **GDK_ROOT must be set** — `gswm` and `fgdku` check `$GDK_ROOT` to determine if they're in a GDK directory
6. **Restart the service that owns the file, not the one that contains it** — see the table above; verify the PID changed
7. **Prefer `bin/rails runner` over `bundle exec rails`** in `$GDK_ROOT/gitlab` (railties is not in the bundle), but expect it to take minutes to boot — for read-only inspection, `gdk psql` is far faster. Note checkpoint tables are partitioned as `p_duo_workflows_checkpoints`
