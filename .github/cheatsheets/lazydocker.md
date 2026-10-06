# LazyDocker cheat sheet

Configuration: [`~/.config/lazydocker/config.yml`](../../.config/lazydocker/config.yml).
Open it with `lzd` from the Compose project directory, or `<leader>td` in
Neovim. The Neovim launcher changes to the current buffer's directory first.
Press `?` for the focused panel's action menu. Open this sheet with `cheat lzd`.

## Memorize first

1. `c` on a container or image offers the custom **Inspect** command in jless.
1. `E` opens a new shell in a running container. `a` attaches to its main process.
1. `R` on a service opens restart, recreate, and rebuild choices.
1. `[` and `]` switch detail tabs without leaving the selected resource.
1. `b` opens bulk actions. Check their scope before running anything destructive.

## How this setup behaves

- Compose commands use `docker compose`, not the legacy `docker-compose` binary.
- The configured log window is 60 minutes, and timestamp display is disabled.
  Different log actions use different templates, so do not assume every view
  has the same limit. The project log command follows the last 300 lines.
- **Inspect container** and **Inspect image** run `docker inspect` in jless.
  Press `q` in jless to return to LazyDocker.
- The main panel wraps lines, and the focused side panel expands vertically.
- File-opening commands use Neovim.

## Navigation and inspection

| Goal | Keys | Notes |
| --- | --- | --- |
| Focus services, containers, or images | `2`, `3`, `4` | `1` is project, `5` volumes, `6` networks |
| Filter a resource list | `/` | Filters the list, not log contents |
| Switch detail tabs | `[` or `]` | For example, logs, stats, or configuration |
| Focus the main panel, then return | `Enter`, then `Esc` | |
| Scroll details without changing selection | `J` or `K` | `C-d` and `C-u` scroll by larger steps |
| Resume automatic scrolling of details | `End` | `Home` jumps to the beginning |
| Cycle normal, half, and fullscreen layouts | `+` or `_` | Forward or backward |
| Open logs | `m` | Project, service, or container panel determines scope |
| Hide or show stopped containers | `e` | Containers panel only |
| Inspect a container or image in jless | `c`, then choose **Inspect** | Custom command |
| Open the first published port in a browser | `w` | Assumes HTTP |

## Container and service lifecycle

| Goal | Keys | Notes |
| --- | --- | --- |
| Open a new shell | `E` | Containers or Services panel |
| Attach to the main process | `a` | Signals can affect the application |
| Stop, restart, or pause | `s`, `r`, `p` | Containers or Services panel |
| Start an existing stopped service | `S` | Services panel |
| Create or update one service | `u` | Runs `docker compose up -d SERVICE` |
| Create or update the project | `U` | Services panel, all project services |
| Choose restart, recreate, or rebuild | `R` | Services panel |
| Take the Compose project down | `D` | Review the menu for volume-removal choices |
| Open removal choices for a resource | `d` | Meaning depends on the panel |
| Open bulk operations | `b` | Review the target set before confirming |

Use **restart** to restart an existing container without applying new Compose
configuration. Use **recreate** after changing container configuration. Use
**rebuild** after changing an image's build inputs. This setup maps recreate to
`up -d --force-recreate` and rebuild to `up -d --build` for the selected service.

Prefer `E` when you need a separate shell. With `a`, you join the container's
existing process. Docker's default detach sequence is `C-p C-q` - `C-c` may
interrupt the application instead.

## Cleanup safety

- Stopping a container preserves it. Removing a container discards its writable
  layer, but named volumes have a separate lifecycle.
- The configured **down with volumes** action uses `docker compose down
  --volumes`. It can delete persistent project data.
- Removing a volume can permanently delete database or application state.
  Check backups and which services use it first.
- Bulk actions can extend beyond the selected resource. Read the command and
  confirmation before using them, especially on a shared Docker host.

## Recipes

**Investigate a failing container.** Press `3`, filter by name with `/`, and
check the logs and stats tabs with `[` and `]`. Press `c` and choose
**Inspect container** to examine mounts, environment, and network settings.
Use `E` if you need to inspect files inside the running container.

**Apply a Compose change.** Launch `lzd` from the project directory, press `2`,
and select the service. Press `R` and choose recreate for a configuration
change, or rebuild for an image change. Check the logs after it starts.

**Extract an inspection field.** Open the custom Inspect command, find the
field in jless, and press `y p` for its exact path or `y y` for the whole value.
See the [jless sheet](jless.md) for structural navigation and search.

Checked on 2026-10-06 against LazyDocker 0.25.2, the tracked configuration, and
the [versioned keybinding reference](https://github.com/jesseduffield/lazydocker/blob/v0.25.2/docs/keybindings/Keybindings_en.md).
