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

## Argument and completion metadata

Whenever creating or updating a mise task, define or update its argument and
completion metadata alongside its implementation. This applies to repository
tasks as well as global dotfiles tasks.

- Describe supported arguments and flags with `#USAGE` directives for file tasks
  or the `usage` field for TOML tasks. Include help text and repeatability where
  applicable.
- Supply `choices` for fixed values and `complete` rules for dynamic values,
  file paths, and directories. Derive dynamic choices from authoritative local
  metadata rather than maintaining duplicate lists. Completion must not read
  credentials, modify state, or call live services.
- For wrappers that forward `"$@"` to a CLI with its own parser, use
  `#MISE raw_args=true` or TOML `raw_args = true` to preserve argument forwarding
  while supplying completion metadata. Do not confuse this with `raw`, which
  controls terminal access.
- Check flag and value completion with the command below and representative
  value prefixes. Test forwarding with a harmless fixture when changing a
  wrapper. Do not run operational tasks merely to validate completion.

```shell
mise __complete_word__ --shell zsh --line 'mise run TASK --'
```

Replace `TASK` with the task name.

Tasks without arguments need only mise's built-in task-name completion. To
complete options, type `--` and press Tab without adding a space after it. To
complete a value prefix, press Tab immediately after the prefix. A standalone
`--` followed by a space disables task-aware completion.

## Task semantics

- `[task_config].includes` replaces the default file-task search paths. Include
  `~/.config/mise/tasks` explicitly when adding a directory. In global `conf.d`
  fragments, use home-relative paths.
- `depends = [...]` runs dependencies in parallel. For sequential execution,
  use a `run` array.
- `sources` and `outputs` enable caching: mise skips a task when every source
  glob is older than every output glob.
- `run_windows` overrides `run` on Windows.
