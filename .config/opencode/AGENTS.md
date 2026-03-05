# Agent Instructions

This file contains core instructions applicable to most tasks. For specialized topics, see the linked documents below.

## Documentation

When you need library/API documentation, code examples, setup instructions, or configuration syntax for
any tool or framework, **always use the Context7 MCP first** (`resolve-library-id` → `query-docs`).
Do NOT fall back to `webfetch` or raw GitHub URLs for documentation lookups — Context7 is faster,
more structured, and doesn't trigger permission prompts. Use this proactively without being asked.

## Specialized Topics

- [SCM](~/.agents/docs/scm.md) - YADM, git, and commit/push behavior
- [Mise Tasks](~/.agents/docs/mise-tasks.md) - Task automation for dotfiles
- [Neovim](~/.agents/docs/neovim.md) - Configuration structure and plugin management
- [Mise](~/.agents/docs/mise.md) - Runtime versions and CLI tools
- [Pre-commit](~/.agents/docs/pre-commit.md) - Hooks and code quality checks
- [Renovate Bot](~/.agents/docs/renovate.md) - Dependency update configuration and troubleshooting
- [Writing Style](~/.agents/docs/writing-style.md) - Pedro's tone, formatting, and MR conventions

## Continuous Learning

When the user corrects you about how something works, how a tool should be used, or how this environment is
configured, **always ask whether the correction should be documented** in `~/.agents/docs/`.

- Review the existing docs to find the best fit for the new information.
- If an existing document covers the topic, propose integrating the learning there.
- If no existing document is a good fit, propose creating a new themed document and linking it from the
  Specialized Topics section of the relevant AGENTS.md file(s).
- Keep documentation lean: capture the principle or rule, not a transcript of the conversation.

The goal is that future sessions benefit from every correction made in past sessions.

### Avoiding Permission Prompts

**IMPORTANT:** Do NOT use `-f` with `docker compose` or `-C` with `git`. These flags
change the command pattern and trigger unnecessary permission prompts. Instead:

- For `docker compose`: use the Bash tool's `workdir` parameter to run from the service
  directory, then use `docker compose config` without `-f`
- For `git`: use the Bash tool's `workdir` parameter instead of `git -C`
- For `git`/`yadm`: do NOT use `--no-pager`. The pager does not activate in
  non-interactive shells, so it is unnecessary and breaks yadm commands.

```bash
# Correct — use workdir parameter on the Bash tool call
# workdir: compose/foo
docker compose config

# Correct — no --no-pager needed (pager is inactive in non-interactive shells)
git log --oneline -5
yadm diff -- ~/.config/opencode/

# Incorrect — triggers permission prompts
docker compose -f compose/foo/docker-compose.yml config
git -C /path/to/repo status

# Incorrect — unnecessary and breaks yadm
git --no-pager diff -- ~/.config/opencode/
yadm --no-pager diff -- ~/.config/opencode/
```
