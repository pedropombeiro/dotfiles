---
name: issue-state
description: Keep a GitLab issue's native Status in sync with its merge requests, and start implementing an issue by assigning it to the current user and setting the active milestone. Use when asked to start work on an issue, update an issue's status as MRs progress, or track issue state through the dev/review/complete lifecycle.
license: MIT
compatibility: opencode
metadata:
  audience: developers
  author: pedropombeiro
  keywords: gitlab, issues, status, work-items, milestone, assignee, lifecycle
  workflow: gitlab
---

# Issue State Tracking Skill

Keeps a GitLab issue's **native Status** aligned with the progress of its merge requests, and
handles the "start implementing this issue" flow (assign to me + set the active milestone + move
the status to *In dev*).

Bundled scripts resolve all project-specific IDs at runtime — the status lifecycle, the current
user, and the active milestone — so nothing is hardcoded and the skill works across projects.

> **Core rule:** always set the **Status**, never the `workflow::*` label. GitLab keeps the
> `workflow::*` label in sync from the status automatically; setting the label directly fights
> that sync.

## When to use

- The user says "start implementing issue X" / "let's pick up issue X".
- The user wants an issue's status updated to reflect where its MRs are.
- Tracking an issue through the dev → review → complete lifecycle as work progresses.

## Status progression rules

Set the status as work progresses, not only at the end:

| Situation | Status |
|-----------|--------|
| Actively implementing; any MR still an open **draft** | **In dev** |
| All of the issue's MRs are in review, closed, or merged (none still a draft) | **In review** |
| MR(s) merged / issue closed | **Complete** — usually set automatically on close |

If any MR is still a draft, keep the issue **In dev** even if others are in review.

Status names must exist in the project's lifecycle. In `gitlab-org/gitlab` the relevant names are
`In dev`, `In review`, and `Complete`; other namespaces may differ — `resolve-statuses.sh` lists
the valid names for any given issue.

## Scripts

All scripts accept an issue reference as either a **full URL**
(`https://gitlab.com/group/project/-/work_items/123` or `.../issues/123`) or an **IID with
`-R owner/repo`** (`123 -R gitlab-org/gitlab`). Invoke them from the repo root as
`.opencode/skills/issue-state/scripts/<name>` (or `scripts/<name>` from this skill's directory);
do not assume they are on `PATH`.

### `start-issue.sh` — start implementing

Assigns the issue to the current user, sets the active milestone (the project/ancestor milestone
whose date range contains today), and sets the status to *In dev*.

```bash
.opencode/skills/issue-state/scripts/start-issue.sh <issue-url>
.opencode/skills/issue-state/scripts/start-issue.sh 123 -R gitlab-org/gitlab
.opencode/skills/issue-state/scripts/start-issue.sh <issue-url> --status "In progress"  # override start status
.opencode/skills/issue-state/scripts/start-issue.sh <issue-url> --no-milestone          # skip milestone
```

### `sync-issue-state.sh` — track progress

Inspects the issue's related and closing MRs and applies the progression rules above. Skips
closed issues and issues with no MRs.

```bash
.opencode/skills/issue-state/scripts/sync-issue-state.sh <issue-url>
.opencode/skills/issue-state/scripts/sync-issue-state.sh <issue-url> --dry-run   # show decision only
```

### `set-issue-status.sh` — set a status by name

Low-level setter used by the other scripts. Resolves the status name against the project's
lifecycle and applies it via the `workItemUpdate` GraphQL mutation.

```bash
.opencode/skills/issue-state/scripts/set-issue-status.sh <issue-url> "In review"
```

### `resolve-statuses.sh` — inspect the lifecycle

Lists the statuses available to an issue (name, id, category), or resolves a single name to its
global ID with `--name`.

```bash
.opencode/skills/issue-state/scripts/resolve-statuses.sh <issue-url>
.opencode/skills/issue-state/scripts/resolve-statuses.sh <issue-url> --name "In dev"
```

## How it works

- **Status** is a native work-item field (GitLab 18.4+, Premium/Ultimate), not a label. It is read
  from the `STATUS` widget and written with the `workItemUpdate` mutation's `statusWidget` input.
- **Allowed statuses** come from the work item type's `widgetDefinitions → allowedStatuses`, so the
  name→ID mapping is discovered live per project.
- **Assignee/milestone** are set through the REST issues API (`PUT projects/:id/issues/:iid`).
- **glab auth**: the scripts call glab through `op plugin run -- glab` (the 1Password shell plugin),
  since the interactive `glab` alias is not available to scripts. Override with `GLAB_CMD` if needed.

## Related skills

- **`glab`** — general GitLab CLI/API operations, work-item and epic details.
- **`mr-workflow`** — MR lifecycle helpers (`gpsup`, `test_mr`, etc.). Branch names encode the issue
  IID (`user/<issue>/<name>`), which is how MRs link back to the issue this skill inspects.

## Agent Guidelines

1. **Set the Status, never the `workflow::*` label** — the label syncs from the status automatically.
2. **Start implementing = `start-issue.sh`** — it assigns you, sets the active milestone, and moves the issue to *In dev* in one step.
3. **Update status as MRs move** — run `sync-issue-state.sh` after pushing/opening/merging MRs, not just at the end.
4. **Keep *In dev* while any MR is a draft** — only advance to *In review* once no MR is still a draft.
5. **Don't fight the close automation** — merging/closing usually sets *Complete*; let it, rather than forcing the status.
6. **Use `--dry-run`** on `sync-issue-state.sh` to preview the decision before changing anything.
7. **Unknown lifecycle?** Run `resolve-statuses.sh` to see the valid status names for that project before setting one.
