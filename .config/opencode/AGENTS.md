# Agent Instructions

This file contains core instructions applicable to most tasks. For specialized topics, see the linked documents below.

## Documentation

Always use Context7 MCP when I need library/API documentation, code generation, setup or configuration steps
without me having to explicitly ask.

## Specialized Topics

- [SCM](~/.agents/docs/scm.md) - YADM, git, and commit/push behavior
- [Mise Tasks](~/.agents/docs/mise-tasks.md) - Task automation for dotfiles
- [Neovim](~/.agents/docs/neovim.md) - Configuration structure and plugin management
- [Mise](~/.agents/docs/mise.md) - Runtime versions and CLI tools
- [Pre-commit](~/.agents/docs/pre-commit.md) - Hooks and code quality checks
- [Renovate Bot](~/.agents/docs/renovate.md) - Dependency update configuration and troubleshooting

### Avoiding Permission Prompts

**IMPORTANT:** Do NOT use `-f` with `docker compose` or `-C` with `git`. These flags
change the command pattern and trigger unnecessary permission prompts. Instead:

- For `docker compose`: use the Bash tool's `workdir` parameter to run from the service
  directory, then use `docker compose config` without `-f`
- For `git`: use the Bash tool's `workdir` parameter instead of `git -C`

```bash
# Correct — use workdir parameter on the Bash tool call
# workdir: compose/foo
docker compose config

# Incorrect — triggers permission prompts
docker compose -f compose/foo/docker-compose.yml config
git -C /path/to/repo status
```
