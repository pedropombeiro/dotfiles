---
name: glab
description: GitLab workflow automation using glab CLI
license: MIT
compatibility: opencode
metadata:
  audience: developers
  workflow: gitlab
---

# GitLab Workflow Skill

GitLab workflow management using `glab` CLI for merge requests, issues, and Git best practices.

For standard GitLab.com MR creation, prefer `gpsup` from the `mr-workflow` skill — it
applies project defaults like milestone and labels automatically. Run it via
[`run-in-tmux-pane`](~/.agents/docs/tmux.md#running-commands-in-a-temporary-tmux-pane).

## Creating Merge Requests

```bash
# Preferred (GitLab.com remotes):
run-in-tmux-pane gpsup

# Simple MR
glab mr create --title "feat: add feature" --description "Brief description"

# Complex MR - write description to file first
glab mr create --title "feat: add feature" --description "$(cat /tmp/mr-description.md)"
```

**Templates:** Check `.gitlab/merge_request_templates/` for project-specific templates.

Use `glab mr create` only when `gpsup` is unavailable or the remote is not GitLab.com.

## Updating Merge Requests

```bash
glab mr update <number> --description "$(cat /tmp/description.md)"
glab mr view <number> -R <owner>/<repo>
```

## Issue Management

```bash
# View / comment
glab issue view <number>
glab issue view <number> --comments -R <owner>/<repo>
glab issue note <number> -m "comment" -R <owner>/<repo>
glab issue note <number> -m "$(cat /tmp/comment.md)" -R <owner>/<repo>

# List (open by default — no --state flag)
glab issue list --label "priority::P1,status::doing" -R <owner>/<repo>
glab issue list --closed -R <owner>/<repo>
glab issue list --all   -R <owner>/<repo>

# Create
glab issue create --title "Bug: title" --description "$(cat /tmp/issue-description.md)"

# Labels — use --label / --unlabel, NEVER +label or -label syntax
glab issue update 123 --label "new-label"
glab issue update 123 --unlabel "old-label"
# Scoped labels auto-replace within their scope — no --unlabel needed:
glab issue update 123 --label "status::doing"   # removes any existing status:: label
```

### Issue State Transitions and Notes

```bash
# Close / reopen
glab api --method PUT "projects/<project_id>/issues/<iid>" -f state_event=close
glab api --method PUT "projects/<project_id>/issues/<iid>" -f state_event=reopen

# Post a comment (note: the body field on PUT is silently ignored — always use POST)
glab api --method POST "projects/<project_id>/issues/<iid>/notes" -f "body=Your comment"
glab api --method POST "projects/<project_id>/issues/<iid>/notes" \
  -f "body=$(cat /tmp/comment.md)"
```

## Work Items

GitLab is migrating issues to work items. The URL shows `/work_items/<iid>` but the REST API is the same.

```bash
# ✅ Use the issues API — same IID, same endpoints
glab api "projects/org%2Fproject/issues/<iid>"
glab api "projects/<project_id>/issues/<iid>/notes"

# ❌ /work_items/ REST endpoint does not exist
glab api "projects/org%2Fproject/work_items/<iid>"   # → 404
```

URL parsing: `https://gitlab.com/org/project/-/work_items/539076`
→ `glab api "projects/org%2Fproject/issues/539076"`

Full details, GraphQL alternative, and group-level work items: **[references/work-items.md](references/work-items.md)**

## Issue Links and Epics

- **Issue links** (`blocked_by`, `relates_to`): [references/issue-links.md](references/issue-links.md)
- **Epics CRUD** (create, list, update, close): [references/epics.md](references/epics.md)
- **Epic comments** (GraphQL read/write, pagination): [references/epic-comments.md](references/epic-comments.md)
- **Nested groups** (`%2F` encoding): [references/nested-groups.md](references/nested-groups.md)

## Epics — Critical Notes

**⚠️ Epic comments require GraphQL** — the REST `/notes` endpoint returns 404.

**Quickest path — use the wrapper scripts:**

```bash
# Read all comments (handles pagination)
epic-notes.sh <group-path> <epic-iid>
epic-notes.sh gitlab-org 16428

# Post a comment
create-epic-note.sh <group-id> <epic-iid> "body"
create-epic-note.sh 9970 16428 "My comment"
```

Scripts are in `scripts/`; GraphQL templates in `assets/graphql/`.

**Manual GraphQL (when you need more control):**

```bash
# iid must be a quoted string: "16428" not 16428 (integer → type error)
glab api graphql -f query='
{
  group(fullPath: "gitlab-org") {
    workItem(iid: "16428") {
      widgets {
        type
        ... on WorkItemWidgetNotes {
          discussions(first: 100) {
            pageInfo { hasNextPage endCursor }
            nodes {
              notes {
                nodes { id body author { username } createdAt }
              }
            }
          }
        }
      }
    }
  }
}'
# If hasNextPage: true → re-run with discussions(first: 100, after: "<endCursor>")
```

**Epic close/reopen** — REST works fine, no GraphQL needed:

```bash
glab api --method PUT "groups/<group_id>/epics/<iid>" -f state_event=close
glab api --method PUT "groups/<group_id>/epics/<iid>" -f state_event=reopen
```

**Nested groups** — REST requires `%2F`; GraphQL uses plain `/`:

```bash
glab api "groups/gitlab-org%2Ffoundations/epics"                    # ✅ REST
glab api "groups/gitlab-org/foundations/epics"                      # ❌ 404
glab api graphql -f query='{ group(fullPath: "gitlab-org/foundations") { ... } }'  # ✅
```

## MR Listing and Filtering

```bash
glab mr list -R <owner>/<repo>                   # open (default)
glab mr list -R <owner>/<repo> --assignee <user>
glab mr list -R <owner>/<repo> --all             # all states
glab mr list -R <owner>/<repo> --merged
glab mr list -R <owner>/<repo> --closed
glab mr list -R <owner>/<repo> --author <user>
```

**Note:** `glab mr list` has no `--state` or `--status` flag. Use `--all`, `--merged`, `--closed`.

## Pipeline Monitoring

```bash
# Check current branch pipeline status
glab ci status

# View pipeline interactively (requires TTY)
glab ci view

# List recent pipelines
glab ci list

# View a specific pipeline's jobs
glab ci get <pipeline-id>

# View job logs
glab ci trace <job-id>
```

**In non-interactive environments (e.g. AI agents):** Use the `gitlab_get_pipeline` MCP tool to poll pipeline status, since `glab ci view` requires a TTY.

## GLQL Queries

To query issues, MRs, or epics across projects/groups, load the **`glab-glql`** skill.

## Git Best Practices

```bash
git checkout -b feat/description    # branch naming
git checkout -b fix/description

# Commit format: type: description (conventional commits)
# Reference issues with full URLs: Closes https://gitlab.com/org/project/-/issues/123
# Use single quotes for special characters: git commit -m 'fix: from MR !123'
```

## Agent Guidelines

1. **Read context first** — `glab issue view` / `glab mr view` before implementing
2. **Use project templates** — check `.gitlab/issue_templates/` and `.gitlab/merge_request_templates/`
3. **Write descriptions to files** — use `$(cat /tmp/description.md)` not inline strings
4. **Reference with full URLs** — `Closes https://gitlab.com/org/project/-/issues/123`
5. **Descriptive commits** — focus on the "why"
6. **Single quotes for special chars** — `git commit -m 'fix: from MR !123'`
7. **Label syntax** — `--label` to add, `--unlabel` to remove; never `+label`/`-label`
8. **Scoped labels** — `--label "status::doing"` auto-removes old `status::*`; no `--unlabel` needed
9. **No `--jq` flag** — glab has no `--jq`; use `| jq '...'` pipe
10. **No `--state`/`--status` on `mr list`** — use `--all`, `--merged`, `--closed`
11. **Work items use the issues API** — `/work_items/<iid>` URLs → `projects/.../issues/<iid>`
12. **Epic comments need GraphQL** — REST `/notes` → 404; use `epic-notes.sh` or manual GraphQL with `first: 100` + pagination
13. **No `-R` for group-level API** — `-R` expects `OWNER/REPO`; group endpoints use `glab api "groups/..."` directly
14. **Nested groups REST: `%2F`** — `groups/org%2Fsubgroup/epics`; unencoded slashes → 404
15. **GraphQL iid is a String** — `workItem(iid: "16428")` not `workItem(iid: 16428)`
16. **`groups/<id>/work_items` is 404** — use `groups/<id>/epics` (REST) or GraphQL
17. **`project.workItems` not `project.workItem`** — singular doesn't exist; use `workItems(first: 1, iid: "IID")`; no `filter:` argument
18. **Epic close/reopen via REST** — `state_event=close`/`reopen` on `PUT groups/<id>/epics/<iid>` works; no GraphQL needed
19. **Prefer `gpsup` for MR creation** — see `scm.md` for details; applies milestone/labels automatically
20. **Fill in the MR description after creation** — open the new MR and update it using the default template in `.gitlab/merge_request_templates/`
