# ADR-002: Use Mise as Runtime and Tool Manager

**Status:** Accepted
**Date:** 2024-06-01

## Context

Development requires managing multiple runtime versions (Node.js, Ruby, Go,
Python) and CLI tools across machines. The tooling should also support
project-local environment variables and task running.

## Decision

Use [mise](https://mise.jdx.dev/) as the single polyglot runtime manager,
replacing asdf and direnv.

## Rationale

- **Single tool** — replaces asdf (versions) + direnv (env vars) + make (tasks)
- **Speed** — written in Rust; noticeably faster activation than asdf
- **Backward-compatible** — reads `.tool-versions` files from asdf
- **Task runner** — `mise run` replaces ad-hoc shell scripts and Makefiles
- **Configuration merging** — `~/.config/mise/conf.d/*.toml` files are merged,
  keeping concerns separated

## Alternatives Considered

| Tool                    | Why not                                               |
| ----------------------- | ----------------------------------------------------- |
| **asdf**                | Shell-based, slower; no built-in env vars or tasks    |
| **nvm / rbenv / pyenv** | One tool per language; more moving parts              |
| **direnv**              | Only env vars; mise subsumes this                     |
| **Nix / Home Manager**  | Powerful but steep learning curve for a dotfiles repo |
