---
name: hammerspoon
description: "Hammerspoon macOS automation. Config in ~/.hammerspoon/. Modules: init.lua, spaces, sleepwake, urlrouter, httpserver, meetings. Keywords: hammerspoon, hs, lua, audiodevice, hotkey, caffeinate, httpserver, Stream Deck, Rectangle Pro, blueutil, AirPods, URL routing. Use when: editing ~/.hammerspoon/ files, debugging Hammerspoon modules, adding Hammerspoon features, checking Hammerspoon logs."
---

# Hammerspoon

macOS automation tool. Installed on **all Darwin machines** via Brewfile cask. Config lives in `~/.hammerspoon/`.

## Architecture

- `init.lua` — Module loader. Loads `hs.ipc` (enables the `hs` CLI to talk to the running instance), then conditionally loads modules that exist on disk (yadm alternates ensure class-gated modules are only present on matching machines).
- `constants.lua` — Shared hardware and tool path constants used across modules (uhubctl, blueutil, USB hub/port assignments, AirPods address).
- `spaces.lua##class.Work` — Applies the Rectangle Pro `External display` layout on every Space switch.
- `sleepwake.lua##class.Work` — Caffeinate watcher for sleep/wake/unlock events. Manages Stream Deck USB power, BusylightHTTP, nginx, and Elgato Control Center. Exports `displaysleep()` for use by other modules.
- `urlrouter.lua##class.Work` — URL-based browser router (replaces Choosy). Hammerspoon is registered as the default HTTP/HTTPS handler via `duti`. Routes `zoom.us/j/` and `zoom.us/my/` links to Zoom.app, everything else to Chrome.
- `meetings.lua##class.Work` — Auto-switches audio to AirPods when Zoom launches (connects via `blueutil` if needed), pauses Spotify, quits eqMac. On Zoom exit: restores previous audio device, resumes Spotify, relaunches eqMac hidden, quits Camo Studio, powers off Elgato Wave USB port.
- `httpserver/` — Modular HTTP server on `localhost:18990`. Sub-modules each return a table of `{ actionName = handlerFn }` that get merged into a single dispatch table.
  - `httpserver/init.lua` — Server skeleton. Parses query params via `hs.http.urlParts`, loads sub-modules, dispatches on `?action=`.
  - `httpserver/triggers.lua##class.Work` — `lock` and `sleep` actions for Home Assistant (Work only, depends on `sleepwake`).
  - `httpserver/notify.lua` — `notify` action for native macOS notifications via `hs.notify`. Maps event types to sounds/subtitles. Click callback focuses iTerm2 and selects the originating tmux pane.

## Key behaviours

| Event                            | Actions                                                                                                                              |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| Space switch                     | Apply Rectangle Pro layout                                                                                                           |
| `systemWillSleep`                | Kill BusylightHTTP, power off Stream Deck USB                                                                                        |
| `screensDidSleep`                | Power off Stream Deck USB                                                                                                            |
| `screensDidUnlock`               | Cycle Stream Deck (async), restart nginx, reopen BusylightHTTP, restart Elgato Control Center, apply Rectangle Pro layout (2s delay) |
| `hammerspoon://displaysleep` URL | Power off Stream Deck, lock screen, sleep display after 2s                                                                           |
| HTTP `?action=lock`              | Lock screen (Work only)                                                                                                              |
| HTTP `?action=sleep`             | Same as `displaysleep` URL handler (Work only)                                                                                       |
| HTTP `?action=notify`            | Send native macOS notification with click-to-focus (all machines)                                                                    |
| Any `http`/`https` URL opened    | Route to Zoom.app (meeting links) or Chrome (everything else) — replaces Choosy (Work only)                                          |
| Zoom launched                    | Connect AirPods via blueutil, switch audio output, pause Spotify, quit eqMac (Work only)                                             |
| Zoom terminated                  | Restore previous audio output, resume Spotify, relaunch eqMac hidden, quit Camo Studio, power off Elgato Wave USB (Work only)        |

## Notify action

Used by `~/.config/opencode/notifier/notify.sh` to deliver OpenCode notifications. The shell script handles the grace period and tmux `@opencode-waiting` check, then delegates to Hammerspoon via `curl`.

Query params: `event`, `message`, `title`, `pane` (tmux pane ID).

Event-to-sound mapping (in `httpserver/notify.lua`):

| Event               | Sound | Subtitle            |
| ------------------- | ----- | ------------------- |
| `complete`          | Glass | Session Complete    |
| `subagent_complete` | Pop   | Subagent Complete   |
| `error`             | Basso | Error               |
| `permission`        | Ping  | Permission Required |
| `question`          | Purr  | Question            |

## Network topology (Home Assistant → laptop)

```
Home Assistant
  → http://gitlab-macbookpro:18989/trigger?action=lock   → nginx → Hammerspoon :18990
  → http://gitlab-macbookpro:18989/trigger?action=sleep   → nginx → Hammerspoon :18990
  → http://gitlab-macbookpro:18989?action=currentpresence → nginx → BusylightHTTP :8989
```

`hs.httpserver` only accepts localhost connections, so nginx is required as a reverse proxy for external access.

## Stream Deck integration

The Stream Deck "lock" button should open the URL `hammerspoon://displaysleep` (configured to open with Hammerspoon). This replaces the previous `Ctrl+Cmd+Q` + `pmset displaysleepnow` approach which had timing issues with USB wake events.

## Stream Deck USB hub location

The Stream Deck XL is connected at `uhubctl` location `2-1.1.2` port `2`. The Elgato Wave microphone is on the same hub at port `1`. If the hub layout changes, update `constants.lua` and verify with `uhubctl --location 2-1.1.2`.

## Rectangle Pro

URL scheme is `rectangle-pro://` (not `rectanglepro://`). Layout is triggered via:

```
open -g "rectangle-pro://execute-layout?name=External%20display"
```

## Related files

- `~/.config/yadm/bootstrap.d/901-configure-hammerspoon-firewall.sh##os.Darwin,class.Work` — Adds Hammerspoon to macOS firewall allowlist (Work only; Personal machines only use localhost)
- `~/.config/yadm/bootstrap.d/941-open-hammerspoon-at-login.sh##os.Darwin` — Launches Hammerspoon at login (all Darwin machines)
- `~/.config/yadm/bootstrap.d/940-open-apps-at-login.sh##os.Darwin,class.Work` — Other Work-only login items (Hammerspoon removed from here)
- `~/.config/opencode/notifier/notify.sh` — OpenCode notifier script that calls Hammerspoon's notify endpoint
- `~/.config/yadm/config_templates/nginx/servers/localhost.conf` — nginx reverse proxy config
- `~/.config/yadm/scripts/defaults.sh##os.Darwin` — Registers Hammerspoon as default HTTP/HTTPS handler via `duti` (for `urlrouter`)
- `~/.config/mise/conf.d/work.toml##class.Work` — `system:fix` task (manual fallback with sudo powers)
- `~/.config/yadm/scripts/run-checks.zsh##class.Work` — Health checks for Hammerspoon, nginx, Busylight, Stream Deck

## Debugging / Logs

Hammerspoon logs to an in-memory console. Read it from the CLI with:

```bash
hs -c "hs.console.getConsole()"
```

This requires `hs.ipc` (loaded in `init.lua`). The output includes all `hs.logger` messages and extension load traces. There are no on-disk log files by default.

## API documentation

Use Context7 (`/hammerspoon/hammerspoon.github.io`) for Hammerspoon API reference and guides — do not guess API signatures. It maps to the Hammerspoon docs site and has broader coverage than the repo entry. Fallback: https://www.hammerspoon.org/docs/

## Development workflow

1. Edit Lua files in `~/.hammerspoon/`
2. Run `stylua` to format (enforced by pre-commit)
3. Reload config: `hs -c "hs.reload()"` (or use run-in-tmux-pane if `hs` needs shell environment)
4. Check logs: `hs -c "hs.console.getConsole()"`
5. `hs.task` objects **must** be stored in module-level variables to prevent garbage collection

## Gotchas

- `hs.task` and `hs.timer` objects are garbage-collected if not stored in a variable — the underlying process/timer is killed immediately.
- `hs.timer.doUntil` checks the predicate **before** running the action — if the predicate is true immediately, the action never fires. Prefer `hs.timer.doEvery` with manual stop.
- Hammerspoon needs explicit Bluetooth permission in System Settings > Privacy & Security > Bluetooth to use `blueutil` via `hs.task`.
- Lua files are formatted by `stylua` via pre-commit. The hook uses `language: system`, so `stylua` must be available on PATH (e.g. via `mise use -g stylua`).
