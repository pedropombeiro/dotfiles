---
name: repo-bootstrap
description: Load and reconcile repo-local GitLab instructions before substantive work
license: MIT
compatibility: opencode
metadata:
  audience: developers
  author: pedropombeiro
  keywords: bootstrap, instructions, routing, repo-context, gitlab
  workflow: gitlab
---

# Repo Bootstrap Skill

Use this skill at the start of non-trivial work in the GitLab repo to assemble the active
instruction set before broad exploration, edits, or command execution.

## Goal

Reduce repeated startup work by turning multiple instruction files into one short runtime checklist.

## When to use

- The task needs more than a quick one-file read or small edit.
- The task touches Git, testing, merge requests, CI/CD, docs, database, or repo workflows.
- You need to know which repo-local rules override global OpenCode behavior.
- The repo auto-loads only a minimal instruction set and task-specific context must be discovered.

## Inputs

Provide one or more task hints when useful:

- `git`
- `testing`
- `merge-requests`
- `ci-cd`
- `database`
- `code-review`
- `frontend`
- `docs`

If no hint is provided, infer the likely task category from the user request.

## Files to inspect first

Always start with:

- `AGENTS.local.md`
- `.ai/AGENTS.md`

Load `.gitlab/duo/chat-rules.md` for testing, git workflow, or weekly-status/report tasks.

Then load matching task modules from `.ai/` and their `.local.md` counterparts when present.

## Precedence

Resolve conflicts in this order:

1. Task-specific repo rules.
2. Repo-local general rules.
3. Global OpenCode rules.
4. Skill defaults.

If two repo-local sources conflict, prefer the more specific task-scoped rule and mention the
conflict in the bootstrap output.

## Output format

Return four short sections only:

### Scope

- State the inferred task type.
- List the files loaded.

### Active rules

- Give 5 to 10 bullets with only the rules that matter for the task.
- Prefer concrete instructions over generic reminders.

### Conflicts resolved

- Note any contradictions you found.
- State which rule wins and why.

### Load next

- Recommend the next repo-local or global skill to load, if any.
- Keep this list short.

## Guardrails

- Do not restate whole files.
- Do not compensate for empty placeholder modules by inventing rules.
- Do not ask the user to choose between conflicting rules unless the conflict changes behavior
  materially and cannot be resolved by precedence.
- If a relevant module is empty, mention that briefly and continue.

## Common GitLab repo outcomes

- Docs or handbook lookup: prefer Glean first.
- Library or framework docs: prefer Context7 first.
- Broad code discovery: prefer Knowledge Graph when available.
- Targeted tracked-file lookup: prefer `git ls-files` and `git grep`.
- GDK update flow: use `fgdku`, not manual update commands.
- ClickHouse tables, schemas, ingestion, or `CH` questions: load `clickhouse` before direct code search.

## Example use

Prompt:

```text
Use repo-bootstrap for a testing task in this repo.
```

Expected shape:

```text
Scope
- Inferred task: testing
- Loaded: AGENTS.local.md, .ai/AGENTS.md, .ai/testing.md, .ai/testing.local.md, .gitlab/duo/chat-rules.md

Active rules
- Run Ruby specs with `bundle exec rspec <file> --format documentation`.
- Run `bundle exec rubocop -A <file>` after editing RSpec files.

Conflicts resolved
- Repo rule preferring Knowledge Graph for broad exploration overrides generic Glob guidance.

Load next
- `tool-routing`
- `run-in-tmux-pane` if the chosen command needs zsh or a TTY.
```
