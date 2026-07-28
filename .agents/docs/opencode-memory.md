# OpenCode Memory

Long-term semantic memory system for OpenCode sessions (project: `opencode-memory`,
installed to `~/.local/share/opencode-memory-install/`). Runs as a local MCP server
(`memory`, `http://localhost:9824/mcp`) plus a plugin loaded from the install's
`plugin` directory. Full docs: `opencode-memory/BOOTSTRAP.md`.

Configuration lives in `~/.config/opencode-memory/config.toml`, tracked by YADM as a
`##class.Work` alt file because it holds machine-specific absolute paths.

## Verifying the Stack

```
curl -s http://localhost:9824/health   # {"status":"ok",...}
~/.local/share/opencode-memory-install/scripts/memory-ctl.sh status
lsof -nP -iTCP:9824 -sTCP:LISTEN       # expect one LISTEN line
launchctl list | grep -i opencode      # expect 3 agents
tail ~/.local/state/opencode-memory/server.error.log
grep -i "LLM:" ~/.local/state/opencode-memory/worker.error.log | tail -1
```

If `curl` is denied by the OpenCode permission rules, the `lsof` and log checks cover
the same ground.

Healthy state is **three** processes: `http_server`, `daemon`, `jobs.worker`.

Two reporting quirks to expect:

- `memory-ctl.sh status` prints `server/daemon/worker: stopped` even when they run
  under launchd — `manual_status()` only looks for pidfiles from manually started
  processes. Trust `http: healthy` plus `launchctl list` instead.
- Services are restarted with `launchctl kickstart -k gui/$UID/<label>`;
  `memory-ctl.sh start` no-ops with "server already healthy" if the HTTP port
  answers, so it will not reload config on its own.

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

## Pinned `mcp` Dependency (do not remove)

The install requires the **1.x** line of the `mcp` PyPI package (the upstream Model
Context Protocol Python SDK). `mcp` 2.0.0 replaced decorator handler registration
(`@server.list_tools()`) with constructor handlers (`Server(..., on_list_tools=...)`),
so on 2.x the server dies at import with:

```
AttributeError: 'Server' object has no attribute 'list_tools'
ERROR:    Application startup failed. Exiting.
```

Nothing listens on 9824 after that, so proactive injection and boot context silently
stop working while the daemon and worker keep running (a partial-failure state that
looks healthy at a glance).

Root cause: `pyproject.toml` declares an unbounded `mcp>=1.0.0` while `uv.lock` pins
`1.27.0`, and `scripts/setup.sh` installs with plain `pip install -e .`, which ignores
the lockfile. `mcp` 2.0.0 was released 2026-07-28, so any install after that date
resolves to the incompatible major.

Fix applied here:

```
~/.local/share/opencode-memory-install/.venv/bin/pip install 'mcp==1.27.0'
```

**Re-apply after every installer re-run** — `setup.sh` runs `pip install -e .` on each
invocation, which can pull 2.x back in. Verify with
`ls -d ~/.local/share/opencode-memory-install/.venv/lib/python3.*/site-packages/mcp-*.dist-info`.
Upstream's own guidance is to constrain the dep (`mcp>=1.28,<2`); until that lands,
this pin is manual. Reported upstream as
[ghavenga/opencode-memory#223](https://gitlab.com/ghavenga/opencode-memory/-/issues/223) —
once it is fixed and the install updated, this pin can be dropped.

## LLM Provider Needs an Absolute Path

The launchd LaunchAgents (`~/Library/LaunchAgents/com.opencode.memory*.plist`) set only
`HF_HUB_OFFLINE` and `TRANSFORMERS_OFFLINE` — **no `PATH`**. Because `opencode` is a
mise shim (`~/.local/share/mise/shims/opencode`), `shutil.which("opencode")` fails
inside the services, and LLM features degrade silently with
`LLM provider 'opencode' not found`.

Set an absolute path in `config.toml`:

```toml
[llm]
provider = "opencode"
command = "/Users/pedropombeiro/.local/share/mise/shims/opencode"
args = ["run", "--dangerously-skip-permissions"]
```

`args` is **not optional**. Setting `command` short-circuits the provider branch that
would otherwise supply the default arguments, so omitting `args` invokes bare
`opencode` with no subcommand. Confirm the fix in the worker log — it logs
`(LLM: True, GitLab: False)` at startup once the provider resolves.

## Proactive Context Injection

There is **no enable flag**. Injection is on whenever the plugin path is present in
`opencode.json`'s `plugin` array; the plugin's hooks fire unconditionally. The
`[proactive_context]` config section only _tunes_ it (`min_relevance_threshold` 0.35,
`max_context_items` 8, `thinking_gate_enabled`, ...) and has no `enabled` key. To turn
injection off you must remove the plugin entry. If the server is down, injection fails
silently rather than erroring.

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
