# Agent Instructions

This file contains core instructions applicable to most tasks. For specialized topics, see the linked documents below.

## Specialized Topics

- [SCM](~/.agent_docs/scm.md) - YADM, git, and commit/push behavior
- [Justfile](~/.agent_docs/justfile.md) - Task automation for dotfiles
- [Neovim](~/.agent_docs/neovim.md) - Configuration structure and plugin management
- [Renovate Bot](~/.agent_docs/renovate.md) - Dependency update configuration and troubleshooting
- [Tmux](~/.agent_docs/tmux.md) - Configuration structure, plugins, and shell integration

## Searching Dotfiles

When searching for configuration files or code in the home directory, use YADM commands for much faster results:

- `yadm ls-files` - List all tracked dotfiles
- `yadm grep <pattern>` - Search content within tracked dotfiles

These commands only search files tracked by YADM, avoiding the slow traversal of the entire home directory.
