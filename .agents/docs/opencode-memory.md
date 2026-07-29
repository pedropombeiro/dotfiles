# OpenCode Memory

Long-term semantic memory system for OpenCode sessions (project: `opencode-memory`,
installed to `~/.local/share/opencode-memory-install/`). Runs as a local MCP server
(`memory`, `http://localhost:9824/mcp`) plus a plugin loaded from the install's
`plugin` directory. Full docs: `opencode-memory/BOOTSTRAP.md`.

Configuration lives in `~/.config/opencode-memory/config.toml`, tracked by YADM as a
`##class.Work` alt file because it holds machine-specific absolute paths.

## Routed Behind lazy-mcp

The memory tools are proxied through lazy-mcp rather than registered directly, so their
schemas are discovered on demand instead of occupying the context window every message.
Two pieces make this work:

- `~/.config/lazy-mcp/servers.json` has a `memory` server pointing at the **local shim**
  `scripts/memory-mcp.sh` — not the daemon's `http://localhost:9824/mcp` URL. The shim
  advertises the consolidated set (`recall`, `remember`, `memory`, `workflow`,
  `memory_shutdown`) and serves `workflow` in-process; fronting the daemon by URL
  instead exposes the raw un-shrunk tool list and `workflow` fails there.
- `opencode.json`'s plugin entry uses the array form with `{ "tools": false }` so the
  plugin skips registering its own `secret_guard_forget` tool (upstream #155). Context
  injection and secret-guard redaction run via hooks and are unaffected — only the tool
  schema is withheld. Reach the tool through lazy-mcp when needed.

`workflow` needs `GITLAB_TOKEN` in the session environment; the shim inherits it from
the shell, which the shared daemon cannot do. Since the token is fetched on demand via
`setup_gitlab_secrets` (1Password) rather than exported by default, `workflow` actions
that call the GitLab API fail until that function has been run in the shell that
launched OpenCode. The plain `memory_*` tools do not need the token.

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

## Troubleshooting: Server Silently Dead After Install/Upgrade

Symptom: `launchctl list | grep opencode` shows all three agents running, but nothing
answers on `:9824` — proactive injection and boot context silently stop working while
looking healthy at a glance. Check `~/.local/state/opencode-memory/server.error.log`
for:

```
AttributeError: 'Server' object has no attribute 'list_tools'
ERROR:    Application startup failed. Exiting.
```

Diagnosis: the `mcp` PyPI package (the upstream Model Context Protocol Python SDK) went
2.0.0 on 2026-07-28, which replaced decorator handler registration
(`@server.list_tools()`) with constructor handlers (`Server(..., on_list_tools=...)`).
`opencode-memory`'s `pyproject.toml` declares an unbounded `mcp>=1.0.0` (while
`uv.lock` pins `1.27.0`), and `scripts/setup.sh` installs with plain `pip install -e .`,
which ignores the lockfile — so any install/upgrade run after that date can resolve to
the incompatible major. Confirm with:

```
ls -d ~/.local/share/opencode-memory-install/.venv/lib/python3.*/site-packages/mcp-*.dist-info
```

Remediation: pin the install to the 1.x line and restart the server:

```
~/.local/share/opencode-memory-install/.venv/bin/pip install 'mcp==1.27.0'
launchctl kickstart -k gui/$UID/com.opencode.memory
```

This is a workaround for
[ghavenga/opencode-memory#223](https://gitlab.com/ghavenga/opencode-memory/-/issues/223)
(unbounded `mcp>=1.0.0`, still open as of 2026-07-28). Once upstream constrains the
dependency (their own stated intent is `mcp>=1.28,<2`), this stops being necessary.
Bootstrap does not pre-apply this pin — see "Fresh Machine Bootstrap" below, which
instead verifies the server actually comes up rather than guessing which `mcp` major
is safe today.

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

## Fresh Machine Bootstrap

Two `yadm` bootstrap.d scripts (both `##class.Work`, since the install is
machine-specific) handle a new work machine end to end:

- `965-ensure-weekly-log.sh` clones the personal weekly-log repo
  (`git@gitlab.com:pedropombeiro/weekly-log.git`, `origin` remote; the
  `gitlab-org/growth/ai/weekly-log-template` template lives as `upstream`) to
  `~/Developer/gitlab.com/pedropombeiro/weekly-log` — the path
  `config.toml##class.Work`'s `ingestion.watch_paths` points at. It is safe to re-run:
  if the directory already exists (e.g. copied over from another machine), it only
  adds missing remotes and never touches an existing worktree's branch or history.
- `970-install-opencode-memory.sh` runs `setup.sh` non-interactively using the
  `[setup]` values already saved in `config.toml##class.Work`
  (`OPENCODE_MEMORY_RUNTIME=python OPENCODE_MEMORY_STARTUP=always
OPENCODE_MEMORY_AGENTS=opencode,claude`), then:
  1. Polls `:9824/health` for up to 60s (absorbing the one-time ~90MB embedding-model
     download) and **fails loudly** with the `server.error.log` tail if the server
     never comes up — this is the same failure class described above, just caught at
     install time instead of discovered later.
  2. Diffs the four yadm-managed files it can touch (`AGENTS.md`, `opencode.json`,
     `servers.json`, `config.toml`) before/after and **fails** if any changed, with a
     `yadm checkout --` remediation hint.
  3. Backfills any existing `brain/<YYYY>/*.md` files into memory via
     `python -m opencode_memory.cli ingest ... --recursive`, guarded by a marker file
     so it only runs once. `insert_memory` (`storage/sqlite.py`) dedupes on
     `(category, content_hash)`, so re-running this (e.g. after copying
     `~/.local/share/opencode-memory/memory.db` from another machine) is a harmless
     no-op beyond re-embedding cost — the marker is a fast-path, not a correctness
     requirement.

Neither script pins `mcp`. If the health-check step fails, consult "Troubleshooting:
Server Silently Dead After Install/Upgrade" above.

`scripts/run-checks.zsh##class.Work` has matching drift checks —
`check_opencode_memory` (3 launchd agents + `:9824` healthy) and
`check_weekly_log_repo` (repo cloned, `brain/<YYYY>/` non-empty) — so a later
`mise run checks` catches the service dying or the repo silently landing on a branch
without content.
