# OpenCode Memory

Long-term semantic memory system for OpenCode sessions (project: `opencode-memory`,
installed to `~/.local/share/opencode-memory-install/`). Runs as a local MCP server
(`memory`, `http://localhost:9824/mcp`) plus a plugin loaded from the install's
`plugin` directory. Full docs: `opencode-memory/BOOTSTRAP.md`.

## Tool Usage

Throughout a session:

- Before working on an MR/issue/epic, call `memory_get_context(entity_ref)` to get history.
- Use `memory_claim_item()` before making changes to prevent conflicts.
- Store important decisions, blockers, and procedures with `memory_remember()`.
- Release claimed items when done with `memory_release_item()`.
- Use `memory_recall(query)` to search for relevant context.

## Session Tracking

When ending a session or summarizing work done, include the session ID (shown in the
session context footer) to enable continuation tracking across sessions.

## Installer Overwrite Hazard

`opencode-memory`'s `scripts/setup.sh` (`setup_agents_md()`) writes
`~/.config/opencode/AGENTS.md` with `echo "$AGENTS_CONTENT" > "$AGENTS_FILE"` — a full
overwrite, not a merge. It skips rewriting only if the file already contains the exact
string `"If you do not see boot context"`.

- Never remove that sentinel line from `~/.config/opencode/AGENTS.md`; it's what keeps
  future installer runs from clobbering the merged file again.
- After any re-run of the installer (`setup.sh`), run `yadm diff` to check whether it
  touched `.config/opencode/AGENTS.md`, `.config/opencode/opencode.json##class.Work`, or
  `.config/lazy-mcp/servers.json##class.Work` and re-merge if needed.
