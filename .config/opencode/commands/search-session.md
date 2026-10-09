---
description: Search previous sessions and open or summarize a match
---

Help me return to a previous OpenCode session. OpenCode already ran the
`session-search` script for my query, and its output follows. Don't load the
`session-search` skill or rerun the search unless a step below asks for it.

!`~/.agents/skills/session-search/scripts/search.py --stdin --format text <<'__SEARCH_SESSION_QUERY__'
$ARGUMENTS
__SEARCH_SESSION_QUERY__
`

Then act on the output:

1. If it says the query is empty, ask me what to search for with the
   `question` tool. Then load the `session-search` skill and run the search it
   describes.
1. If it found no sessions, tell me which searches ran, from its `Searches`
   line, and stop.
1. Otherwise, if the last search on the `Searches` line includes `+tools`, say
   in one sentence that nothing matched the conversation text and these matches
   come from tool calls and their output. Then ask both of these questions in a
   single `question` tool call, without listing the results in a message first:
   1. **Which session?** Add one option per session shown, with sessions in the
      current project (`same project: yes`) first. Use the session title as the
      label. In the description, put the session ID, the date of the last
      match, `current project` when it applies, and a short excerpt. Skip this
      question when only one session was found.
   1. **What should I do with it?** Offer **Switch and close search tab**,
      recommended when a shown session is in the current project. Explain
      that it keeps the search conversation in history. Also offer **Open
      session**, which keeps the search tab open, and **Summarize here**. Offer
      **Show more matches** only when more sessions were found than shown.
1. Act on my answers:
   - **Switch and close search tab**: call `open_session` with the session ID
     and `close_source: true`. This closes the source tab after opening the
     destination, without deleting history. With tabs disabled, it only
     switches sessions. It keeps the tab open if both sessions share a root.
     If the session belongs to another project, or the tool fails, show the
     reason and tell me to reopen it with `opencode --session <id>`.
   - **Open session**: call `open_session` with the session ID, omitting
     `close_source` to keep the search tab open. If the
     session belongs to another project, or the tool fails, show the reason
     and tell me to reopen it with `opencode --session <id>`.
   - **Summarize here**: summarize what the session discussed about my query.
     Start from the excerpts. When you need more context, load the
     `session-search` skill and rerun the search with `--session <id>`, more
     `--excerpts`, and a larger `--context`.
   - **Show more matches**: load the `session-search` skill, rerun the search
     with a larger `--limit`, and ask again.
