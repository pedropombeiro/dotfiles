# Agent Instructions

This file contains core instructions applicable to most tasks. For specialized topics, see the linked documents below.

## Specialized Topics

- [Shell](~/.agent_docs/shell.md) - Zsh configuration, zinit plugins, functions
- [Bootstrap](~/.agent_docs/bootstrap.md) - YADM bootstrap scripts for system setup
- [Tmux](~/.agent_docs/tmux.md) - Configuration structure, plugins, and shell integration
- [OpenCode](~/.agent_docs/opencode.md) - Policy overrides and runtime behaviors

## Dotfiles (YADM)

**Always use `yadm` instead of `git`** when working with files in:

- `~/.config/`
- `~/.shellrc/`
- `~/.agent_docs/`
- `~/.claude/`
- Any dotfiles in `~` (the home directory is not a git repo)

NOTE: By `~/` we take it to mean the home directory (`$HOME`).

When searching for configuration files or code in the home directory, use YADM commands for much faster results:

- `yadm ls-files` - List all tracked dotfiles
- `yadm grep <pattern>` - Search content within tracked dotfiles

These commands only search files tracked by YADM, avoiding the slow traversal of the entire home directory.

## Searching files or file content in a home directory

Always favor searching using `yadm ls-files` and `yadm grep` over `glob`/`find` and `grep` tools, given the large
amount of unrelated files present under a home directory.

## Path Resolution Edge Case

**Important:** When checking if the current working directory is a git repository, be aware that paths
may look different but resolve to the same location via symlinks.
Always resolve paths to their canonical form (e.g., using `readlink -f`) before assuming two different-looking paths
are actually different locations.
This prevents incorrectly treating the home directory as a regular git repository when it's actually managed by YADM.
