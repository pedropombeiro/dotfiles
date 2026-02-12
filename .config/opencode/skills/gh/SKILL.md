---
name: gh
description: GitHub workflow automation using gh CLI
license: MIT
compatibility: opencode
metadata:
  audience: developers
  workflow: github
---

# GitHub Workflow Skill

GitHub workflow management using `gh` CLI for pull requests, issues, and Actions runs.

## Pull Requests

```bash
# Simple PR
gh pr create --title "feat: add feature" --body "Brief description"

# Complex PR - write description to file first
gh pr create --title "feat: add feature" --body "$(cat /tmp/pr-description.md)"
```

**Templates:** Check `.github/pull_request_template.md` or `.github/PULL_REQUEST_TEMPLATE/` for project-specific templates and follow their structure.

## Issue Management

```bash
# View issue details
gh issue view <number>

# List issues with filters
gh issue list --label "bug" --assignee "@me" --state open

# Create issue - write description to file first
gh issue create --title "Bug: issue title" --body "$(cat /tmp/issue-description.md)"
```

**Templates:** Check `.github/ISSUE_TEMPLATE/` for project-specific templates and follow their structure.

## Actions Runs

```bash
# List runs for current repo
gh run list

# View run details and failed logs
gh run view <run-id>
gh run view <run-id> --log-failed

# Re-run a failed workflow
gh run rerun <run-id>

# Watch a run until completion
gh run watch <run-id>
```

## Quick Reference

```bash
# List issues/PRs
gh issue list --label "bug" --assignee "@me"
gh pr list --author "@me"

# View details
gh issue view 123
gh pr view 456

# Review and merge
gh pr review 456 --approve
gh pr merge 456 --merge
```

## Agent Guidelines

1. **Use gh CLI** - Never use `curl`/`wget`/`webfetch` to `github.com` or `api.github.com`
2. **Use gh api as escape hatch** - Prefer `gh api` for endpoints not covered by first-class commands
3. **Read context first** - Use `gh issue view` or `gh pr view` before implementing
4. **Use project templates** - Check `.github/ISSUE_TEMPLATE/` and `.github/PULL_REQUEST_TEMPLATE/`
5. **Write descriptions to files** - Create markdown in `/tmp/` then use `$(cat /tmp/description.md)`
6. **Reference properly** - Link issues/PRs in commits: `Closes #123`, `Related to #456`
