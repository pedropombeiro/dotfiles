# Mise Tasks

[Mise](https://mise.jdx.dev/tasks/) is used as the task runner for dotfile management tasks.

## Task Locations

- **TOML tasks**: `~/.config/mise/conf.d/tasks.toml` (shared across all systems)
- **TOML tasks (work)**: `~/.config/mise/conf.d/tools.work.toml`
- **TOML tasks (macOS)**: `~/.config/mise/config.toml##default` (brew, network)
- **File tasks**: `~/.config/mise/tasks/` (complex scripts)
- **File tasks (work)**: `~/.config/mise/tasks-work/` (registered by `conf.d/tools.work.toml`)

## Available Tasks

Do not mirror the task list here — it drifts. `mise tasks` prints the live set with
descriptions, and `mise run <task>` (alias `mise r`) runs one.

Task descriptions come from the `#MISE description=` header (file tasks) or the
`description` key (TOML tasks), so `mise tasks` is always ground truth.
