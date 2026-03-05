# ADR-003: Use Zinit as Zsh Plugin Manager

**Status:** Accepted
**Date:** 2024-01-01

## Context

Zsh startup time is critical for interactive shell responsiveness. The plugin
manager must support lazy loading and turbo mode to keep shell startup fast
while still providing a rich plugin ecosystem.

## Decision

Use [zinit](https://github.com/zdharma-continuum/zinit) (community fork) as
the Zsh plugin manager.

## Rationale

- **Turbo mode** — deferred loading via `wait` / `lucid` keeps startup under
  ~200 ms even with many plugins
- **Fine-grained control** — `ice` modifiers allow per-plugin load order,
  compilation, and conditional loading
- **Oh-my-zsh compatibility** — can load OMZ plugins and libraries without
  sourcing the full framework
- **Binary installs** — `from"gh-r"` fetches pre-built binaries directly from
  GitHub Releases

## Alternatives Considered

| Tool                   | Why not                                                          |
| ---------------------- | ---------------------------------------------------------------- |
| **Oh-my-zsh (full)**   | Slow startup; loads everything eagerly                           |
| **zplug**              | Abandoned; slower than zinit                                     |
| **antidote / sheldon** | Viable but less mature turbo-loading support at time of adoption |
| **No manager**         | Manual sourcing is error-prone and hard to maintain              |
