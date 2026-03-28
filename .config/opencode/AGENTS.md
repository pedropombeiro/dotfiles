# Agent Instructions

This file contains the global rules that apply across repositories. Load the linked docs only when
the task needs them.

## Core Rules

- For library and framework documentation, use Context7 first.
- Before the first MCP call in a session, use `lazy-mcp_describe_commands` to inspect the schema.
- In unfamiliar repos, read local `AGENTS.md`, `CLAUDE.md`, and task-index docs before broad exploration.
- Prefer repo-local skills over rediscovering documented workflows.

## Search Routing

- For GitLab docs, runbooks, handbook content, or other company knowledge, use Glean first.
- For code or config in tracked git files, prefer `git ls-files` and `git grep`.
- Use `Glob` and `Grep` only when untracked or ignored files matter.

## Permission Prompt Hygiene

- Use the Bash tool `workdir` parameter instead of `git -C`.
- Do not use `--no-pager` with `git` or `yadm`.
- Use the Bash tool `workdir` parameter instead of `docker compose -f` when possible.

## Continuous Learning

- When the user corrects tool usage or environment behavior, ask whether the rule should be documented in `~/.agents/docs/`.
- Keep additions lean and principle-based.
- If the correction is about routing work through existing repo docs or skills, use the relevant doc-learning workflow.

## Specialized Topics

- [SCM](~/.agents/docs/scm.md) - YADM, git, and commit/push behavior
- [Mise Tasks](~/.agents/docs/mise-tasks.md) - Task automation for dotfiles
- [Neovim](~/.agents/docs/neovim.md) - Configuration structure and plugin management
- [Mise](~/.agents/docs/mise.md) - Runtime versions and CLI tools
- [Pre-commit](~/.agents/docs/pre-commit.md) - Hooks and code quality checks
- [Renovate Bot](~/.agents/docs/renovate.md) - Dependency update configuration and troubleshooting
- [Writing Style](~/.agents/docs/writing-style.md) - Pedro's tone, formatting, and MR conventions
- [GDK Dotfiles](~/.agents/docs/gdk-dotfiles.md) - Personal files synced into `$GDK_ROOT/gitlab`
- [Developer Directory](~/.agents/docs/developer-directory.md) - Repo clone path convention (`~/Developer/<forge>/<owner>/<repo>`)
