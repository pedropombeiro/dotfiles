# Hammerspoon

macOS automation tool used on `class.Work` machines. Config lives in `~/.hammerspoon/`.

## Architecture

- `init.lua` — Module loader. Requires `hs.ipc` for CLI/URL event support, then conditionally loads modules that exist on disk (yadm alternates ensure only `##class.Work` modules are present on Work machines).
- `spaces.lua##class.Work` — Applies the Rectangle Pro `External display` layout on every Space switch.
- `sleepwake.lua##class.Work` — Caffeinate watcher for sleep/wake/unlock events. Manages Stream Deck USB power, BusylightHTTP, nginx, and Elgato Control Center. Exports `displaysleep()` for use by other modules.
- `httpserver.lua##class.Work` — HTTP server on `localhost:18990` handling `/trigger?action=lock` and `/trigger?action=sleep` from Home Assistant (proxied through nginx on port 18989).

## Key behaviours

| Event                            | Actions                                                                                                                              |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| Space switch                     | Apply Rectangle Pro layout                                                                                                           |
| `systemWillSleep`                | Kill BusylightHTTP, power off Stream Deck USB                                                                                        |
| `screensDidSleep`                | Power off Stream Deck USB                                                                                                            |
| `screensDidUnlock`               | Cycle Stream Deck (async), restart nginx, reopen BusylightHTTP, restart Elgato Control Center, apply Rectangle Pro layout (2s delay) |
| `hammerspoon://displaysleep` URL | Power off Stream Deck, lock screen, sleep display after 2s                                                                           |
| HTTP `/trigger?action=lock`      | Lock screen                                                                                                                          |
| HTTP `/trigger?action=sleep`     | Same as `displaysleep` URL handler                                                                                                   |

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

The Stream Deck XL is connected at `uhubctl` location `2-1.1.2` port `2`. If the hub layout changes, update the constants in `sleepwake.lua` and verify with `uhubctl --location 2-1.1.2 --port 2`.

## Rectangle Pro

URL scheme is `rectangle-pro://` (not `rectanglepro://`). Layout is triggered via:

```
open -g "rectangle-pro://execute-layout?name=External%20display"
```

## Related files

- `~/.config/yadm/bootstrap.d/901-configure-hammerspoon-firewall.sh##os.Darwin,class.Work` — Adds Hammerspoon to macOS firewall allowlist
- `~/.config/yadm/bootstrap.d/940-open-apps-at-login.sh##os.Darwin,class.Work` — Launches Hammerspoon at login
- `~/.config/yadm/config_templates/nginx/servers/localhost.conf` — nginx reverse proxy config
- `~/.config/mise/conf.d/work.toml##class.Work` — `system:fix` task (manual fallback with sudo powers)
- `~/.config/yadm/scripts/run-checks.zsh##class.Work` — Health checks for Hammerspoon, nginx, Busylight, Stream Deck

## Stylua

Lua files are formatted by `stylua` via pre-commit. The hook uses `language: system`, so `stylua` must be available on PATH (e.g. via `mise use -g stylua`).
