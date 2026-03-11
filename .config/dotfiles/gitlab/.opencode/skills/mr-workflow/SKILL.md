---
name: mr-workflow
description: GitLab merge request lifecycle helpers (push, test, tidy, apply patches)
license: MIT
compatibility: opencode
metadata:
  audience: developers
  workflow: gitlab
---

# MR Workflow Skill

Shell functions for the merge request lifecycle: creating MRs, running branch specs,
calculating MR throughput, tidying stale to-dos, and applying MR patches locally.

All functions are zsh functions loaded from `~/.shellrc/zshrc.d/functions/`.

## Available Commands

### `gpsup`

Pushes the current branch and creates/configures a merge request with appropriate defaults
when the remote is on `gitlab.com`. Falls back to a plain `git push --set-upstream` for
non-GitLab remotes.

```bash
gpsup
gpsup --force-with-lease
```

Extracts the issue IID from the branch name (`user/<issue>/<name>`) and delegates to a
Ruby helper (`scripts/gitlab-helpers.rb`) for MR creation.

Automatically applies project defaults (milestone, issue labels, and team labels) using
GitLab push options.

### `test_mr`

Derives the corresponding spec files for all `.rb` files changed in the current branch
vs `master`, then runs them with `bundle exec rspec`.

```bash
test_mr
```

Mapping rules:
- `app/` → `spec/`
- `lib/` → `spec/lib/`
- `ee/lib/` → `ee/spec/lib/`
- `app/controllers/` → `spec/requests/`
- Files already ending in `_spec.rb` are used as-is

### `mr_rate`

Calculates the MR merge rate of a given GitLab user via the GitLab API.
Defaults to the current user (`$USER`).

```bash
mr_rate              # current user
mr_rate someuser     # specific user
```

### `todo_tidy`

Marks as done all GitLab to-do items for MRs that are already closed or merged
where the action was `review_requested`.

```bash
todo_tidy
```

Uses `glab api` to paginate through all MergeRequest to-dos and mark stale ones done.

### `tryout`

Downloads a `.diff` from a GitLab MR URL and applies the patch to the current working tree.

```bash
tryout https://gitlab.com/gitlab-org/gitlab/-/merge_requests/96461
```

Applies with `git apply` and stages all changes (excluding `bin/`).

## Agent Guidelines

1. **Use `test_mr`** to quickly validate branch changes without manually listing spec files
2. **Run `todo_tidy`** when the user wants to clean up stale review to-dos
3. **Use `tryout`** to apply an MR's changes locally for testing without checking out the branch
4. **Use `gpsup` for MR creation** — it is non-interactive and applies milestone/labels automatically; do not use `glab mr create` for the standard workflow
5. **Run `gpsup` via the Ruby script directly** — see `scm.md` § "How to run `gpsup`" for the exact command; do not check for its existence with `type`/`which`
6. **Update the MR description after creation** — open the newly created MR and write a reviewer-friendly description based on the default template in `.gitlab/merge_request_templates/`
