---
name: session-search
description: "Find previous OpenCode sessions that contain a keyword or sentence. Use when the user asks which earlier session discussed something, wants to find where a phrase, command, or decision came up, or wants to return to a past conversation."
version: 1.0.0
license: MIT
compatibility: opencode
metadata:
  author: pedropombeiro
  audience: developers
---

# session-search

Search past OpenCode sessions with
[scripts/search.py](scripts/search.py). The script opens the local OpenCode
database read-only, matches the query against message text, and prints JSON
with the newest matches first.

The OpenCode session-list API cannot do this. Its `search` parameter matches
session titles only.

## Run the search

Run the script by its full path so the global permission rule for skill
scripts allows it without a prompt:

```sh
~/.agents/skills/session-search/scripts/search.py "<keyword or sentence>"
```

Pass the user's wording as one quoted argument. Matching is literal and
case-insensitive, so don't add wildcards or regular expressions.

| Option | Use it when |
| ------ | ----------- |
| `--words` | A phrase search finds nothing. Matches sessions that contain every word, in any message. |
| `--include tools` | The text could appear in a command, a file read, or tool output. |
| `--include reasoning,system` | The user asks about model reasoning or harness messages. |
| `--directory <path>` | The user names a repository or project. Matches the path and its subdirectories. |
| `--since YYYY-MM-DD`, `--until YYYY-MM-DD` | The user gives a time frame. `--until` excludes that day. |
| `--limit <n>`, `--excerpts <n>`, `--context <chars>` | You need more sessions, more excerpts, or more surrounding text. |
| `--include-current` | You need to search the current session too. It's excluded by default. |

User messages, assistant replies, compaction summaries, and session titles are
always searched.

## Present the results

1. Filter the JSON with `jq` when it's large. For example:
   `... | jq '.sessions[] | {id, title, last_match}'`.
1. List each matching session with its title, ID, directory, and date of the
   last match. Quote the most relevant excerpt.
1. Mention `total_sessions` when it's larger than the number shown.
1. Tell the user they can reopen a session with `opencode --session <id>`.

If nothing matches, retry with `--words`, then `--include tools`. Tell the user
which searches you ran.

## Limitations

- The search folds case for ASCII letters only. Accented letters must match
  the case of the query.
- The script depends on OpenCode's internal database schema: `session_message`
  and `session_v2`, or `session` on older versions. If it exits with an
  unsupported schema error, inspect the tables with `sqlite3 -readonly`
  before changing the script.
- Set `--db` to search a database other than
  `${XDG_DATA_HOME:-~/.local/share}/opencode/opencode.db`.
