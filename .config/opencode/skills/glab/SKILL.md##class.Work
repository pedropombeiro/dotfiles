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

## Creating Merge Requests

```bash
# Simple MR
glab mr create --title "feat: add feature" --description "Brief description"

# Complex MR - write description to file first
glab mr create --title "feat: add feature" --description "$(cat /tmp/mr-description.md)"
```

**Templates:** Check `.gitlab/merge_request_templates/` for project-specific templates and follow their structure.

## Updating Merge Requests

```bash
# Update description from file
glab mr update <number> --description "$(cat /tmp/description.md)"

# View MR details
glab mr view <number> -R <owner>/<repo>
```

## Issue Management

```bash
# View issue details
glab issue view <number>

# List issues with filters
glab issue list --label "priority::P1,status::doing"

# Create issue - write description to file first
glab issue create --title "Bug: issue title" --description "$(cat /tmp/issue-description.md)"
```

**Templates:** Check `.gitlab/issue_templates/` for project-specific templates and follow their structure.
**References:** Link related issues using `#123` syntax and use appropriate labels/milestones.

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

## Epic Management

`glab` has no built-in epic commands. Use the REST API via `glab api`:

```bash
# View epic details
glab api "groups/<group-id>/epics/<epic-iid>"

# Read epic description
glab api "groups/<group-id>/epics/<epic-iid>" | python3 -c "import sys,json; print(json.load(sys.stdin).get('description',''))"

# Update epic description - write to file first, then use $(cat)
glab api -X PUT "groups/<group-id>/epics/<epic-iid>" -f "description=$(cat /tmp/epic-description.md)"

# Update epic title
glab api -X PUT "groups/<group-id>/epics/<epic-iid>" -f "title=New Title"
```

## Git Best Practices

**Branch naming:**

```bash
git checkout -b feat/description
git checkout -b fix/description
git checkout -b refactor/description
```

**Commit messages:**

- Format: `type: description` (conventional commits)
- Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`
- Explain the "why" not just the "what"
- Reference: `Closes #123`, `Related to !456`
- Use single quotes for special characters: `git commit -m 'fix: resolve MR !123'`

## Quick Reference

```bash
# List issues/MRs
glab issue list --label "bug,P1"
glab mr list --author @me

# View details
glab issue view 123
glab mr view 456

# Update MR
glab mr update 456 --description "$(cat /tmp/new-description.md)"
```

## Agent Guidelines

1. **Read context first** - Use `glab issue view` or `glab mr view` before implementing
2. **Use project templates** - Check `.gitlab/issue_templates/` and `.gitlab/merge_request_templates/` for project-specific formats
3. **Write descriptions to files** - Create markdown in `/tmp/` then use `$(cat /tmp/description.md)`
4. **Reference properly** - Link issues/MRs in commits: `Closes #123`, `Related to !456`
5. **Descriptive commits** - Focus on the "why" behind changes
6. **Quote special characters** - Use single quotes: `git commit -m 'fix: from MR !123'`
