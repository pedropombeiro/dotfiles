# Trippy cheat sheet

Configuration: [`~/.config/trippy/trippy.toml##template`](../../.config/trippy/trippy.toml%23%23template).
Run `trip HOST`. On macOS the config turns on unprivileged mode, so `sudo` isn't
needed. On the NAS, `admin` is uid 0, so privileged mode works directly. The
key bindings are upstream defaults. Press `h` or `?` in the TUI for the full list.

The `trip` shell function adds the GeoLite2 City database once
`mise run geoip:update` has downloaded it, so each hop shows its city and
country code. The bootstrap reads the MaxMind credentials from the
`MaxMind GeoLite2` item in 1Password. Dotfiles updates refresh the database.
The function also looks up each hop's network owner (AS) through Team Cymru's
DNS service. That needs the `resolv` resolver, which skips VPN-only DNS. When
internal hostnames show as IPs, run `trip -r system HOST`: choosing a resolver
turns the AS lookup off.

## Memorize first

1. `d` shows the selected hop's details, including every address it answers from.
1. `C-f` freezes the display, so you can read a hop before it updates.
1. `c` opens the latency chart for all hops; `m` opens the world map.
1. `C-r` clears the collected data, for a clean run after you change something.
1. `--tcp -P 443` traces the path HTTPS takes when a firewall drops ICMP.

## Reading the hops table

| Goal | Keys | Notes |
| --- | --- | --- |
| Select a hop | `Up` or `Down` | `Esc` clears the selection |
| Show the hop's details | `d` | Cycle its addresses with `.` and `,` |
| Show IPs, hostnames, or both | `i`, `n`, or `b` | The config defaults to both |
| Show AS information | `z` | Shows which network owns each hop |
| Show more or fewer addresses per hop | `]` or `[` | `}` and `{` jump to the maximum or minimum |
| Switch between targets | `Left` or `Right` | When tracing several hosts |
| Quit and keep the table on screen | `Q` | `q` quits normally |

## Charts and flows

| Goal | Keys | Notes |
| --- | --- | --- |
| Toggle the latency chart | `c` | Zoom with `=` and `-` |
| Toggle the world map | `m` | Circles show each hop's location accuracy |
| Toggle the flows view | `f` | Needs `-R paris` or `-R dublin` |
| Open the settings | `s` | `1` to `7` jump to a tab |
| Clear the DNS cache | `C-k` | After a DNS change |

## Command-line options

| Goal | Command | Notes |
| --- | --- | --- |
| Trace through a firewall that drops ICMP | `trip --tcp -P 443 HOST` | `--udp` traces with UDP |
| Trace several hosts at once | `trip HOST1 HOST2` | Switch with `Left` and `Right` |
| Follow load-balanced paths | `trip --udp -R paris HOST` | Then press `f` for flows |
| Force IPv4 or IPv6 | `trip -4 HOST` or `trip -6 HOST` | |
| Save a report instead of the TUI | `trip -m markdown -C 10 HOST` | `-m json` or `-m csv` too |
| Show full city and country names | `trip --tui-geoip-mode long HOST` | `location` shows coordinates |
| Trace from a specific interface | `trip -I en0 HOST` | Compare Wi-Fi and Ethernet |

## Recipes

**Find where packet loss starts.** Run `trip 1.1.1.1` and watch the `Loss%`
column. Loss that starts at one hop and continues to the target is real. Loss on
a single middle hop only usually means that router rate-limits ICMP replies.

**Check the Wi-Fi path inside the LAN.** Run
`trip ap-u6pro.infra.pombei.ro router.lan.pombei.ro` and switch between them
with `Left` and `Right`. High jitter on the first hop points at Wi-Fi rather
than the ISP.

**Attach a trace to a bug report or chat.** Run
`trip -m markdown -C 20 HOST` and paste the table.
