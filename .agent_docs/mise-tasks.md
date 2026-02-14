# Mise Tasks

[Mise](https://mise.jdx.dev/tasks/) is used as the task runner for dotfile management tasks.

## Task Locations

- **TOML tasks**: `~/.config/mise/conf.d/tasks.toml` (shared across all systems)
- **TOML tasks (macOS)**: `~/.config/mise/config.toml##default` (brew, network)
- **File tasks**: `~/.config/mise/tasks/` (complex scripts)

## Available Tasks

```bash
mise tasks        # List all tasks
mise run <task>   # Run a task (alias: mise r)
```

### Dotfiles

| Task                   | Description                          |
| ---------------------- | ------------------------------------ |
| `dotfiles:install`     | Bootstrap the system via yadm        |
| `dotfiles:update`      | Run update scripts                   |
| `dotfiles:pull`        | Fetch and reset dotfiles from origin |
| `dotfiles:checkhealth` | Run dotfile health checks            |
| `dotfiles:fix`         | Run pre-commit hooks with auto-fix   |
| `dotfiles:lint`        | Run pre-commit hooks (lint only)     |

### Git

| Task         | Description                     |
| ------------ | ------------------------------- |
| `git:push`   | Push (auto-detects yadm vs git) |
| `git:commit` | AI-assisted commit message      |

### Brew (macOS only)

| Task           | Description                        |
| -------------- | ---------------------------------- |
| `brew:dump`    | Dump Homebrew packages to Brewfile |
| `brew:cleanup` | Remove unlisted Homebrew packages  |

### Network (macOS only)

| Task                   | Description                  |
| ---------------------- | ---------------------------- |
| `network:wifi-traffic` | Sniff AP traffic via tcpdump |
