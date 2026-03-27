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

See `references/WORKFLOW.md` for PR preparation, body formatting, and workflow checks.

## Issue Management

See `references/WORKFLOW.md` for issue-body formatting and preparation guidance.

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

See `references/WORKFLOW.md` for the detailed workflow and drafting rules.
