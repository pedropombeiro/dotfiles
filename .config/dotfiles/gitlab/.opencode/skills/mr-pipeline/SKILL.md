---
name: mr-pipeline
description: "Use for cross-MR pipeline coordination: block until a *different* MR merges, then create a fresh pipeline for yours (e.g. waiting for a revert to land). Does NOT triage pipeline failures — load gitlab-babysit-mr for that."
license: MIT
compatibility: opencode
metadata:
  audience: developers
  author: pedropombeiro
  workflow: gitlab
---

# MR Pipeline Tools Skill

Helper scripts for **cross-MR pipeline coordination**: blocking until some *other* MR merges, then
creating a fresh pipeline for yours. The canonical case is waiting for a revert to land on `master`
before re-running your MR.

## Scope — this skill vs. `gitlab-babysit-mr`

These two are complementary, not alternatives.

| Need | Use |
|------|-----|
| Block until a *different* MR merges | `wait_for_mr_merge` (here) |
| Create a **new** pipeline (re-resolves the merge ref against current `master`) | `run_mr_pipeline` (here) |
| Watch *your* MR's pipeline and triage failures (flaky / master-broken / lint / real) | `gitlab-babysit-mr` |
| **Retry** jobs or an existing pipeline | `gitlab-babysit-mr` |

The distinction in row 2 matters: retrying a pipeline re-runs jobs within the existing pipeline and
keeps the old merge ref. Only creating a new pipeline picks up a fixed `master`. `gitlab-babysit-mr`
only retries, so it cannot substitute for `run_mr_pipeline` in the revert scenario.

Typical combined flow: wait for the revert, create a fresh pipeline, then hand off to
`gitlab-babysit-mr` to nurse it to green.

## Available Commands

Both commands are installed at `~/.local/bin/` and accept either a **full MR URL** or a plain **MR IID**.

### `wait_for_mr_merge`

Polls a merge request until it reaches `merged` (exit 0) or `closed` (exit 1) state.

```bash
# Wait using full URL
wait_for_mr_merge https://gitlab.com/gitlab-org/gitlab/-/merge_requests/226808

# Wait using IID + repo flag
wait_for_mr_merge 226808 -R gitlab-org/gitlab

# Custom poll interval (default: 30s)
wait_for_mr_merge 226808 -R gitlab-org/gitlab -i 60
```

**Options:**

| Flag | Description |
|------|-------------|
| `-R <repo>` | Repository in `OWNER/REPO` format (inferred from URL or current repo) |
| `-i <seconds>` | Poll interval in seconds (default: 30) |

### `run_mr_pipeline`

Triggers a new merge request pipeline via the GitLab API (`POST /projects/:id/merge_requests/:iid/pipelines`).

```bash
# Trigger using full URL
run_mr_pipeline https://gitlab.com/gitlab-org/gitlab/-/merge_requests/226128

# Trigger using IID + repo flag
run_mr_pipeline 226128 -R gitlab-org/gitlab
```

**Options:**

| Flag | Description |
|------|-------------|
| `-R <repo>` | Repository in `OWNER/REPO` format (inferred from URL or current repo) |

## Chained Usage

Wait for a blocking MR to merge, then immediately trigger a new pipeline for your MR:

```bash
wait_for_mr_merge https://gitlab.com/gitlab-org/gitlab/-/merge_requests/226808 && \
  run_mr_pipeline https://gitlab.com/gitlab-org/gitlab/-/merge_requests/226128
```

Once the fresh pipeline is running, hand off to `gitlab-babysit-mr` to watch it and triage any
failures.

### `wait_gdk_mr_merged`

Zsh function (`~/.shellrc/zshrc.d/functions/`) that waits for an MR to be merged,
with Home Assistant webhook notifications. Has two modes:

```bash
# Poll by MR IID (uses GitLab API)
wait_gdk_mr_merged 226808

# Poll by branch pruning (no argument — watches for the current branch's remote to be pruned)
wait_gdk_mr_merged
```

Sends `waiting_for_mr_merge` webhooks to Home Assistant (`on` while waiting, `off` when done).
Supports Ctrl-C to abort gracefully.

**Note:** This is the original GDK-specific version. Prefer `wait_for_mr_merge` for new usage
as it supports full URLs, configurable intervals, and any GitLab repository.

## Dependencies

- `glab` (authenticated via `GITLAB_TOKEN`)
- `jq`
- `curl` (for `wait_gdk_mr_merged` Home Assistant webhooks)

## Agent Guidelines

1. **Use full URLs when available** — they're self-contained and don't require `-R`
2. **Chain with `&&`** — `wait_for_mr_merge` exits 0 on merge, 1 on close, making it safe to chain
3. **Prefer Bash tool** — run these commands via the Bash tool; they produce output on stderr
4. **Non-interactive** — `wait_for_mr_merge` and `run_mr_pipeline` are fully non-interactive and safe for agent use
5. **POST requests** — `run_mr_pipeline` uses `glab api` to POST; ensure `GITLAB_TOKEN` has `api` scope
6. **Prefer `wait_for_mr_merge` over `wait_gdk_mr_merged`** — it's more flexible and supports any repo
7. **Don't triage failures here** — this skill only coordinates *when* pipelines run. For classifying
   and acting on failures, load `gitlab-babysit-mr`
