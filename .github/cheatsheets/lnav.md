# lnav cheat sheet

Configuration: [`~/.lnav/config.json`](../../.lnav/config.json), with the
Gruvbox theme and highlights for IP addresses, color literals, and XML.
Open several logs with `lnav FILE1 FILE2`, or include rotations with
`lnav -R FILE`. The file arguments are your input paths. Recognized logs merge
into a timestamp-ordered view. Open this sheet with `cheat lnav`.

## Memorize first

1. `e` and `w` jump to errors and warnings. `E` and `W` go backward.
1. `:filter-in` and `:filter-out` reduce noise without changing the source files.
1. `;` queries logs with SQL. Include `log_line` to jump back from results with `V`.
1. `p` shows parsed fields for the focused message.
1. `m` bookmarks a message. `u` and `U` move between bookmarks.

## Navigate an incident

| Goal | Keys or command | Notes |
| --- | --- | --- |
| Search by regex | `/` | `n` and `N` move between matches |
| Jump to the next or previous error | `e` or `E` | Recognized log levels |
| Jump to the next or previous warning | `w` or `W` | |
| Jump to a timestamp | `:goto 2026-10-06T14:30:00` | Replace with the incident time |
| Move forward or backward a day | `d` or `D` | Time-based views |
| Find a slowdown in message rate | `s` or `S` | Next or previous |
| Show the message-rate histogram | `i` | `z` zooms in, `Z` zooms out |
| Switch to the histogram at the same time | `I` | Keeps the focused timestamp in sync |
| Show parsed fields | `p` | Check the format and available SQL columns |
| Pretty-print displayed content | `P` | Useful for JSON embedded in logs |
| Focus files and filters | `Tab` | Opens the configuration panel |
| Pause or resume loading new data | `=` | Useful while reading a live stream |
| Toggle word wrapping | `C-w` | |
| Return to the previous view | `q` | At the outermost view, quits lnav |

## Filter without losing context

| Goal | Command or keys | Notes |
| --- | --- | --- |
| Include messages matching a regex | `:filter-in request_id=abc123` | Replace the regex with your identifier |
| Exclude repetitive messages | `:filter-out healthcheck` | Preview highlights matches before you execute |
| Disable or delete one regex filter | `:disable-filter healthcheck` or `:delete-filter healthcheck` | Use the original pattern |
| Toggle all filters | `C-f` | Compare filtered messages with surrounding context |
| Filter by parsed values | `:filter-expr :log_level = 'error'` | SQL expression with colon-prefixed column names |
| Clear the SQL expression filter | `:clear-filter-expr` | Regex filters remain separate |
| Hide messages before or after a time | `:hide-lines-before 14:30` or `:hide-lines-after 15:00` | Absolute or relative dates |
| Clear time bounds | `:show-lines-before-and-after` | |

Press `:` and double-tap `Tab` for command completion. Filters, bookmarks, and
other view state can persist between sessions. `C-r` resets session state,
including bookmarks, so use targeted filter commands when you want to keep them.

## Query and extract fields

Press `;` and enter a query. For example, count recognized messages by level:

```sql
SELECT log_level, count(*) AS messages
FROM all_logs
GROUP BY log_level
ORDER BY messages DESC
```

To find messages and return to their source position:

```sql
SELECT log_line, log_time, log_body
FROM all_logs
WHERE log_body LIKE '%timeout%'
ORDER BY log_time DESC
LIMIT 50
```

In the results, focus a row and press `V` to return to its `log_line` in the
log view. `v` switches views without that position jump. `F5` reruns the query
after new data arrives.

For values embedded in otherwise unstructured messages, create a search table:

```text
:create-search-table durations duration=(?<duration>\d+)
;SELECT avg(CAST(duration AS REAL)) AS mean_duration FROM durations
```

Named regex captures become columns. Change the pattern to match your messages
and add units to your result name when you know them.

The repository also tracks a [UniFi log format](../../.config/lnav/formats/installed/unifi_log.json)
with fields such as `SRC`, `DST`, `PROTO`, and `DPT`. Its tracked path is under
`~/.config/lnav`, while this installation reports `~/.lnav` as its configuration
directory. Check `p` for recognition before assuming the `unifi_log` SQL table
is available.

## Bookmarks and export

| Goal | Keys or command | Notes |
| --- | --- | --- |
| Mark or unmark the focused message | `m` | `C-x` toggles cursor mode to focus another visible line |
| Mark a range from the previous bookmark | `M` | |
| Visit the next or previous bookmark | `u` or `U` | |
| Copy marked lines | `c` | Clipboard |
| Clear marked lines | `C` | |
| Write marked lines | `:write-to incident.txt` | Overwrites the destination |
| Write the current view | `:write-view-to filtered.txt` | Use from the log view for a filtered log export |
| Export SQL results as CSV | `:write-csv-to results.csv` | Exports query results, not marked messages |
| Export SQL results as JSON | `:write-json-to results.json` | |

Use a new output path to preserve existing files. Review exported logs for
credentials and private information before sharing them. The write commands
support `--anonymize`, but still review the result.

## Recipes

**Trace one request across rotated logs.** Open the current file with `lnav -R
FILE`, search for the request ID, then use `:filter-in` with that ID. Toggle
filters with `C-f` when you need surrounding events. Mark useful messages with
`m` and export them with `:write-to incident.txt`.

**Investigate a burst of errors.** Press `i` to find a spike in the histogram,
then return to the log view with `q`. Use `e` to visit errors, `p` to inspect
parsed fields, and the SQL level-count query to summarize the loaded logs.

**Measure repeated duration fields.** Create the `durations` search table,
query its numeric values, and export the result with `:write-csv-to`. Press
`F5` to refresh results if the log is still growing.

Checked on 2026-10-06 against lnav 0.14.1 and its
[hotkey](https://docs.lnav.org/en/v0.14.1/hotkeys.html) and
[command](https://docs.lnav.org/en/v0.14.1/commands.html) references.
