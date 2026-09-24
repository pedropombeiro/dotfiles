# Mise Tasks

[Mise](https://mise.jdx.dev/tasks/) is used as the task runner for dotfile management tasks.

## Task Locations

- **TOML tasks**: `~/.config/mise/conf.d/tasks.toml` (shared across all systems)
- **TOML tasks (work)**: `~/.config/mise/conf.d/tools.work.toml`
- **TOML tasks (macOS)**: `~/.config/mise/config.toml##default` (brew, network)
- **File tasks**: `~/.config/mise/tasks/` (complex scripts)
- **File tasks (work)**: `~/.config/mise/tasks-work/` (registered by `conf.d/tools.work.toml`)

## Available Tasks

Use `mise tasks` for the current task list with
descriptions, and `mise run <task>` (alias `mise r`) runs one.

Task descriptions come from the `#MISE description=` header (file tasks) or the
`description` key (TOML tasks), so `mise tasks` is always ground truth.

## Task usage headers

Define file-task arguments with `#USAGE` directives. `#MISE usage=...` is
unsupported and causes mise to reject the task file.

```bash
#!/usr/bin/env bash
#MISE description="Build with sourcemaps"
#USAGE arg "<package>" help="Package to build"
```

## Task semantics

- `[task_config].includes` replaces the default file-task search paths. Include
  `~/.config/mise/tasks` explicitly when adding a directory. In global `conf.d`
  fragments, use home-relative paths.
- `depends = [...]` runs dependencies in parallel. For sequential execution,
  use a `run` array.
- `sources` and `outputs` enable caching: mise skips a task when every source
  glob is older than every output glob.
- `run_windows` overrides `run` on Windows.
