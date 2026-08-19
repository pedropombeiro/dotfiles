# Agent Instructions

This file contains the global rules that apply across repositories. Load the linked docs only when
the task needs them.

## Session Context

Session context (boot gates, blockers, reminders) is automatically injected at the start of each
session and after compaction. Boot gates (⛔) are standing instructions - follow them when the
relevant situation arises.

**If you do not see boot context** (no boot gates, no blockers section, no reminders) in the system
prompt after this AGENTS.md section, call `get_boot_context()` to load it manually. This is a
fallback for when automatic injection fails.

## Core Rules

- For library and framework documentation, use Context7 first.
- MCP call order is `lazy-mcp_list_commands` -> `lazy-mcp_describe_commands` -> `lazy-mcp_invoke_command`. Never pass a command name to `describe_commands` that `list_commands` did not return; guessing a plausible name is the most common cause of a failed schema lookup.
- `describe_commands` appears batch-atomic: one invalid name can discard schemas for valid names in the same call. Skip it entirely for commands already invoked successfully in the current session.
- Do not preflight MCP servers unless you actually plan to use them.
- In unfamiliar repos, read local `AGENTS.md`, `CLAUDE.md`, and task-index docs before broad exploration.
- Prefer repo-local skills over rediscovering documented workflows.
- Never post or reply to issues, MRs/PRs, comments, discussions, chat, or any external channel without explicit user approval. Draft the content and ask for confirmation first.
- Before drafting or replying to any GitLab prose (MR descriptions, review comments, issue updates, team messages) or a multi-line commit message body, read `~/.agents/docs/writing-style.md` first.

## Search Routing

- For GitLab docs, runbooks, handbook content, or other company knowledge, use Glean first.
- For Pedro's personal notes, memos, and saved snippets, use the `memos` MCP server.
- For code or config in tracked git files, prefer `git ls-files` and `git grep`.
- Use `Glob` and `Grep` only when untracked or ignored files matter.

## Permission Prompt Hygiene

- Use the Bash tool `workdir` parameter instead of `git -C`.
- Do not use `--no-pager` with `git` or `yadm`.
- Use the Bash tool `workdir` parameter instead of `docker compose -f` when possible.
- Decode JSON with `jq`, which is pre-approved. Avoid `python3 -c` for parsing JSON.
- When chaining shell commands with `&&`, put each subcommand on its own line, end intermediate lines with ` && \`, and indent continuation lines with two spaces. Example:

  ```
  cmd1 && \
    cmd2 && \
    cmd3
  ```

## File Conventions

- Always set the executable bit on new shell scripts (`chmod +x`). Scripts without it will silently fail to run from boot hooks, cron, or task runners.

## Continuous Learning

- When the user corrects tool usage or environment behavior, ask whether the rule should be documented in `~/.agents/docs/`.
- Keep additions lean and principle-based.
- If the correction is about routing work through existing repo docs or skills, use the relevant doc-learning workflow.

## Specialized Topics

- [SCM](~/.agents/docs/scm.md) - YADM, git, and commit/push behavior
- [Mise Tasks](~/.agents/docs/mise-tasks.md) - Task automation for dotfiles
- [Neovim](~/.agents/docs/neovim.md) - Configuration structure and plugin management
- [Mise](~/.agents/docs/mise.md) - Runtime versions and CLI tools
- [hk](~/.agents/docs/hk.md) - Git hooks and code quality checks
- [Renovate Bot](~/.agents/docs/renovate.md) - Dependency update configuration and troubleshooting
- [Writing Style](~/.agents/docs/writing-style.md) - Pedro's tone, formatting, and MR conventions
- [Google Developer Documentation Style](~/.agents/skills/google-dev-docs-style/SKILL.md) - Technical prose style,
  local overrides, and Vale checks
- [GDK Dotfiles](~/.agents/docs/gdk-dotfiles.md) - Personal files synced into `$GDK_ROOT/gitlab`
- [Developer Directory](~/.agents/docs/developer-directory.md) - Repo clone path convention (`~/Developer/<forge>/<owner>/<repo>`)
- [OpenCode Memory](~/.agents/docs/opencode-memory.md) - Long-term memory tools and installer caveats
- [Tool Usage](~/.agents/docs/tool-usage.md) - Workarounds for tool-layer failures (large `write` truncation)
