---
name: session-search
description: "Find previous OpenCode sessions that contain a keyword or sentence. Use when the user asks which earlier session discussed something, wants to find where a phrase, command, or decision came up, or wants to return to a past conversation."
version: 1.3.0
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
with the newest matches first. Add `--format text` for a compact listing.

The OpenCode session-list API cannot do this. Its `search` parameter matches
session titles only.

## Run the search

Run the script by its full path so the global permission rule for skill
scripts allows it without a prompt:

```sh
~/.agents/skills/session-search/scripts/search.py "<keyword or sentence>"
```

Pass the user's wording as one quoted argument, or on standard input with
`--stdin`. Matching is literal and case-insensitive, so don't add wildcards or
regular expressions.

When a search finds nothing, the script retries it in the same run: first with
`--words` for a multi-word query, then with tool output included. The
`searches` field lists each search it ran, and `mode` and `include` describe
the one that produced the results.

| Option | Use it when |
| ------ | ----------- |
| `--words` | The words of the query may not appear together. Matches sessions that contain every word, in any message. |
| `--include tools` | The text could appear in a command, a file read, or tool output. Searching tool output is several times slower. |
| `--include reasoning,system` | The user asks about model reasoning or harness messages. |
| `--no-fallback` | You need the results of exactly the search you requested. |
| `--session <id>` | You need more matches from one session, for example to summarize it. |
| `--directory <path>` | The user names a repository or project. Matches the path and its subdirectories. |
| `--current-project` | The user asks about the current project. Matches every worktree of its repository. |
| `--since YYYY-MM-DD`, `--until YYYY-MM-DD` | The user gives a time frame. `--until` excludes that day. |
| `--limit <n>`, `--excerpts <n>`, `--context <chars>` | You need more sessions, more excerpts, or more surrounding text. |
| `--include-current` | You need to search the current session too. It's excluded by default. |

User messages, assistant replies, compaction summaries, and session titles are
always searched.

The script reads the current session from `$OPENCODE_SESSION_ID`. Without it,
the script takes the current project from the working directory and can't
exclude the current session. Command shell blocks, such as the one in
`/search-session`, don't set the variable.

## Present the results

1. Filter the JSON with `jq` when it's large. For example:
   `... | jq '.sessions[] | {id, title, same_project, last_match}'`.
1. List each matching session with its title, ID, directory, and date of the
   last match. Quote the most relevant excerpt. List sessions where
   `same_project` is `true` first, and mark them as part of the current
   project.
1. Mention `total_sessions` when it's larger than the number shown.
1. When the script fell back to tool output, which means `include` contains
   `tools` and you didn't request it, say that nothing matched the conversation
   text and the matches come from tool calls and their output.

If nothing matches, tell the user which searches the script ran, from the
`searches` field.

## Act on a session

The `/search-session` command runs the script before the agent starts and
includes these steps in its prompt. When the user wants to return to a session
in any other way, ask what to do with the `question` tool. Ask both questions in
the same call:

1. If several sessions match, ask which one to use. Label each option with the
   session title and put the session ID and date in its description.
1. Ask what to do with the chosen session. Offer only the actions that apply:
   - **Switch and close search tab**: only when `same_project` is `true`.
     Recommend it first. Close this tab after opening the destination, keeping
     the search conversation in history.
   - **Open session**: only when `same_project` is `true`. Keep this tab open.
   - **Summarize here**: rerun the search with `--session <id>`, more
     `--excerpts`, and a larger `--context`, and summarize the matches in this
     conversation.
   - **Show more matches**: only when `total_sessions` is larger than the
     number shown. Rerun the search with a larger `--limit`.
1. To switch and close the search tab, call `open_session` with its ID and
   `close_source: true`. For **Open session**, omit `close_source`. The tool
   focuses the session's tab, or switches to it, in the terminal that shows
   this session. If the tool is unavailable or fails, show its error and tell
   the user to reopen the session with `opencode --session <id>`.
   `open_session` comes from the `session-open` plugin in
   `~/.config/opencode/local-plugins/server/session-open`. See its
   `README.md`.

Closing the search tab does not delete the session. When tabs are disabled,
the tool switches sessions without closing a tab. It also keeps the tab open
when the destination belongs to the same root session.

For a session of another project, tell the user to reopen it with
`opencode --session <id>`; `open_session` rejects it.

## Limitations

- The search folds case for ASCII letters only. Accented letters must match
  the case of the query.
- The script depends on OpenCode's internal database schema: `session_message`
  and `session_v2`, or `session` on older versions. If it exits with an
  unsupported schema error, inspect the tables with `sqlite3 -readonly`
  before changing the script.
- Set `--db` to search a database other than
  `${XDG_DATA_HOME:-~/.local/share}/opencode/opencode.db`.
