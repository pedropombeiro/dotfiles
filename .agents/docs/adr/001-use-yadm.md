# ADR-001: Use YADM for Dotfiles Management

**Status:** Accepted
**Date:** 2024-01-01

## Context

Managing dotfiles across multiple machines (macOS and Linux, personal and work)
requires a tool that tracks files in-place without symlink farms and supports
platform-specific variants.

## Decision

Use [YADM](https://yadm.io/) (Yet Another Dotfiles Manager).

## Rationale

- **In-place tracking** — files live at their real paths; no symlink indirection
- **Alternate files** — built-in `##os.*`, `##class.*`, `##distro.*` suffixes
  handle platform and context variants without scripting
- **Thin wrapper around git** — familiar CLI, easy to script, full git
  functionality (branches, stash, bisect)
- **Bootstrap system** — `yadm bootstrap` runs numbered scripts for
  first-time machine setup
- **Encryption support** — available if needed (currently unused; 1Password
  handles secrets instead)

## Alternatives Considered

| Tool              | Why not                                                     |
| ----------------- | ----------------------------------------------------------- |
| **Bare git repo** | No alternate-file support; manual `.gitignore` gymnastics   |
| **GNU Stow**      | Symlink-based; no built-in platform variants                |
| **chezmoi**       | Templating adds complexity; alternate files cover our needs |
