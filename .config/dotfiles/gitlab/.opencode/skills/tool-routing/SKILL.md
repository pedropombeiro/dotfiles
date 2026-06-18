---
name: tool-routing
description: "Use when choosing the right lookup and execution tools for GitLab repo work"
license: MIT
compatibility: opencode
metadata:
  audience: developers
  author: pedropombeiro
  keywords: routing, tools, glean, context7, knowledge-graph, tmux
  workflow: gitlab
---

# Tool Routing Skill

Use this skill before searching, reading docs, or executing commands when the best tool is not
obvious. The goal is to avoid repeated tool-selection mistakes and unnecessary permission prompts.

## Goal

Map task intent to the smallest correct tool sequence.

## Inputs

Classify the work into one of these intents:

- `library-docs`
- `gitlab-docs`
- `company-knowledge`
- `clickhouse-schema`
- `repo-code-search-broad`
- `repo-code-search-targeted`
- `known-file-read`
- `interactive-command`
- `long-running-command`

If several intents apply, choose the primary one first and mention the fallback.

## Output format

Return four short sections only:

### Intent

- State the inferred intent.

### Primary tool

- Name the first tool to use.
- Include the preferred command sequence when relevant.

### Fallback

- Give one or two fallbacks only.

### Avoid

- List the specific tools or patterns to avoid for this case.

## Routing table

### `library-docs`

- Primary: Context7.
- Fallback: none unless Context7 lacks the library.
- Avoid: `webfetch`, raw GitHub URLs, `man`.

### `gitlab-docs`

- Primary: Glean chat.
- Fallback: Glean search when raw results are necessary.
- Avoid: local repo search, `webfetch`, `gitlab_documentation_search`.

### `company-knowledge`

- Primary: Glean chat.
- Fallback: Glean search with filters.
- Avoid: local grep-like tools.

### `clickhouse-schema`

- Primary: `clickhouse` skill.
- Fallback: `Read` known schema files or targeted `git ls-files` and `git grep`.
- Avoid: broad `Glob` and `Grep` before trying the repo-local ClickHouse workflow, especially when the table name is already known.
- Avoid: docs or company-knowledge MCP tools unless the user is explicitly asking for documentation or process context.

### `repo-code-search-broad`

- Primary: Knowledge Graph when available.
- Fallback: `git ls-files` and `git grep`.
- Avoid: `Glob` for tracked files unless untracked or ignored files matter.

### `repo-code-search-targeted`

- Primary: `git ls-files` and `git grep`.
- Fallback: `Read` for known files, Knowledge Graph for structural follow-up.
- Avoid: open-ended `Glob` and `Grep` unless git-scoped tools are insufficient.

### `known-file-read`

- Primary: `Read`.
- Fallback: `git ls-files` if the path is uncertain.
- Avoid: shell `cat`, `head`, `tail`.

### `interactive-command`

- Primary: `run-in-tmux-pane`.
- Fallback: normal Bash only if the command is confirmed non-interactive.
- Avoid: ad hoc shell workarounds for missing zsh functions, PATH, or TTY.

### `long-running-command`

- Primary: normal Bash when the command is non-interactive.
- Fallback: `run-in-tmux-pane` if it also needs zsh init, auth state, or a TTY.
- Avoid: short Bash timeouts that outlive neither the command nor the tmux wrapper.

## GitLab repo-specific notes

- For docs on `docs.gitlab.com`, handbook, runbooks, and internal process, use Glean first.
- For ClickHouse tables, schemas, ingestion, or `CH` questions in this repo, load `.opencode/skills/clickhouse/SKILL.md` first.
- For broad code discovery in this repo, Knowledge Graph takes precedence over generic file globbing.
- For tracked code lookup with a clear pattern, use `git ls-files` and `git grep`.
- For GDK shell functions like `fgdku`, `gpsup`, and `test_mr`, use `run-in-tmux-pane`.

## Example use

Prompt:

```text
Use tool-routing for a broad code search in this repo.
```

Expected shape:

```text
Intent
- repo-code-search-broad

Primary tool
- Knowledge Graph

Fallback
- `git ls-files` and `git grep`

Avoid
- `Glob` for tracked files
- docs lookup tools
```
