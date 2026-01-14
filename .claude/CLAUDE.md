# Agent Instructions

This file contains core instructions applicable to most tasks. For specialized topics, see the linked documents below.

## Critical: Repository Management

**Git commands on the `~` directory are managed through `yadm` instead of `git`.**

When working in the home directory (`~`), use `yadm` commands instead of `git` commands for version control operations.

## Git Commit/Push Behavior

When committing/pushing code, first attempt to do it without output (e.g., `git push > /dev/null 2>&1`) to
minimize token usage. Only display output if the operation fails and diagnostics are needed.

## Specialized Topics

For task-specific guidance, reference these documents as needed:

- [Neovim](~/.agent_docs/neovim.md) - Configuration structure and plugin management
- [Renovate Bot](~/.agent_docs/renovate.md) - Dependency update configuration and troubleshooting
- [Tmux](~/.agent_docs/tmux.md) - Configuration structure, plugins, and shell integration
