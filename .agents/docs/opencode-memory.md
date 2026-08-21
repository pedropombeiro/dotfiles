# OpenCode Memory

Long-term semantic memory system for OpenCode sessions (project: `opencode-memory`,
upstream now brands it GHMEM). Runs as a local MCP server
(`memory`, `http://localhost:9824/mcp`) plus a plugin. Full docs:
`opencode-memory/BOOTSTRAP.md`.

> **Work Mac only.** This describes the _Python_ runtime installed to
> `~/.local/share/opencode-memory-install/` via `setup.sh`, under launchd. The QTS NAS
> previously ran a Rust build of the same project; that deployment was removed, so
> nothing here applies to the NAS.

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

Read-only `curl` requests are allowed by the OpenCode permission rules. The `lsof`
and log checks provide alternative health checks.

Healthy state is **three** processes: `http_server`, `daemon`, `jobs.worker`.

Two reporting quirks to expect:

- `memory-ctl.sh status` prints `server/daemon/worker: stopped` even when they run
  under launchd — `manual_status()` only looks for pidfiles from manually started
  processes. Trust `http: healthy` plus `launchctl list` instead.
- Services are restarted with `launchctl kickstart -k gui/$UID/<label>`;
  `memory-ctl.sh start` no-ops with "server already healthy" if the HTTP port
  answers, so it will not reload config on its own.

### Config Changes Need Every Reader Restarted

Each service reads `config.toml` once at startup, so a setting is only live in the processes
restarted since the edit. Several settings are read by more than one service, and a partial
restart fails silently: the feature works but appears disabled.

| Section                             | Worker                     | HTTP server                                     | Daemon            |
| ----------------------------------- | -------------------------- | ----------------------------------------------- | ----------------- |
| `[observability]`                   | schedules the snapshot job | renders `/dashboard` and `/observability/trend` | —                 |
| `[token_usage]`                     | schedules the snapshot job | renders the dashboard's spend panel             | —                 |
| `[ingestion]` watch paths           | —                          | —                                               | watches the paths |
| `[llm]`, `ingestion.llm_extraction` | gates all LLM jobs         | —                                               | —                 |

Both `[observability]` and `[token_usage]` bit this way on 2026-08-07: the worker restart
scheduled the jobs and rows accumulated, but the dashboard kept reporting the feature disabled
because the HTTP server still held the old config. When unsure, restart all three:

```
launchctl kickstart -k gui/$UID/com.opencode.memory
launchctl kickstart -k gui/$UID/com.opencode.memory.daemon
launchctl kickstart -k gui/$UID/com.opencode.memory.worker
```

Check what the HTTP server currently believes rather than trusting the config file:

```
curl -s 'http://localhost:9824/observability/trend?hours=24' \
  | jq '{snapshots_enabled, token_enabled: .token_lifetime.enabled}'
```

Avoid restarting the worker repeatedly in quick succession. A job claimed by a worker that is
killed mid-run is reclaimed, and once reclaims exceed `max_retries` it is marked dead with
`death_reason = crash_looped`. Three restarts inside three minutes during the v0.18.1 upgrade
killed one `ConceptExtraction` and one `EffectivenessAnalysis` job this way. Those are recorded
in `dead_jobs` and are not LLM failures.

## Tool Usage

Throughout a session:

- Before working on an MR/issue/epic, call `get_context(entity_ref)` to get history.
- Use `claim_item()` before making changes to prevent conflicts.
- Store important decisions, blockers, and procedures with `remember()`.
- Release claimed items when done with `release_item()`.
- Use `recall(query)` to search for relevant context.

The stdio shim consolidates the full tool surface behind `memory(action=...)`.

Those five are the common-path tools, **not** the whole surface. Confirm anything
beyond them (`edit_memory`, `archive_memory`, `set_reminder`, `resolve_blocker`,
`get_by_id`, the `queue_*` and `graph_*` families, etc.) with
`lazy-mcp_list_commands` before use.

## Session Tracking

When ending a session or summarizing work done, include the session ID (shown in the
session context footer) to enable continuation tracking across sessions.

## Upgrades

As of v0.18.1, upstream constrains the Python MCP SDK to `<2`, fixing the former
unbounded-dependency startup failure. The current venv may remain on `mcp==1.27.0`; it is
compatible. Do not manually pin it unless an older installation still declares an unbounded
dependency.

Use `scripts/setup.sh` for upgrades rather than a bare `git pull`: it updates the release
channel, rebuilds the untracked `plugin/dist/` JavaScript that OpenCode actually loads, and
refreshes macOS LaunchAgents. It runs `git reset --hard` and `git clean -fd`, so export and
commit any required local patch before running it. The project-attribution workaround is stored
in `~/.agents/patches/opencode-memory-auto-project.patch`; reapply it after each upgrade and
restart all three services.

The setup script overwrites the YADM-tracked `~/.config/opencode/AGENTS.md`. Confirm that file
is clean before upgrading, then restore it with `yadm checkout -- .config/opencode/AGENTS.md`
afterward. Setup can also add Claude Code hooks when `setup.agents` includes `claude`; retain
them if that integration is wanted.

Before a version carrying storage migrations, stop the HTTP server, daemon, and worker and take
a snapshot of `memory.db`, `memory.db-wal`, `memory.db-shm`, and `vectors/`. The v0.18.1 update
was verified on 2026-08-07: schema version 9 migrated to 15, including inert single-user memory
visibility columns, the existing reminder survived, and project-scoped Tier 1 capture still
resolved correctly after the workaround was reapplied.

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

## Session Capture And LLM Gate

Passive OpenCode and Claude Code ingestion records `conversation_summary` rows containing
session metadata (title, message count, tools, entities, and a first-prompt excerpt). These
are not durable extracted knowledge and lifecycle cleanup archives them after 90 days.

The plugin's Tier 1 salient-turn capture is enabled unconditionally by
`~/.shellrc/rc.d/opencode-memory.sh`, which exports `OPENCODE_MEMORY_TIER1_CAPTURE=1`.
It uses the deterministic salience gate and encoder only: it does not make LLM calls.

There are two delivery paths for this setting:

- The shell file covers OpenCode launched directly from a terminal. A shell only exports it
  when started after the file exists, so `exec zsh` or a new pane is required; restarting
  OpenCode in an old shell is insufficient.
- `~/.config/tmux/tmux.conf` sets it in tmux's global environment. This covers the usual
  tmux and `opencode.nvim` path: its `tmux split-window <cmd>` launches OpenCode directly
  and bypasses the login shell.

Verify a running instance inherited the setting with:

```
ps eww -p <opencode-pid> | tr ' ' '\n' | grep OPENCODE_MEMORY_TIER1_CAPTURE
```

OpenCode launched by a GUI Neovim instance outside tmux still needs Neovim to have inherited
the shell setting; re-exec its parent shell or restart Neovim after changing the shell file.

`ingestion.llm_extraction` is misleadingly named. It is the worker's master LLM-capability
gate, so `false` disables all scheduled jobs that require an LLM, including knowledge and
concept extraction, effectiveness analysis, CREDIT reflection, and LLM CONTRADICTS linking.
It was enabled on 2026-08-07 to process concept and effectiveness-analysis backlogs. Expect
about 264 provider calls/day while these drain: concept extraction processes ten memories every
two hours, and effectiveness analysis rechecks three injections every 30 minutes. Reassess the
cost and failure rate after 48 hours.

The periodic `KnowledgeExtraction` job currently has no passive-ingestion input: it queries
`conversation` memories, while the daemon calls `extract_session_summary()` and stores only
`conversation_summary`. Do not enable `llm_extraction` expecting it to mine normal sessions
until upstream fixes this regression. In upstream commit `7dbed6c` (v0.3.0, 2026-05-10), the
three-process refactor dropped both full-conversation and pattern-insight ingestion from the
daemon. `extract_session_memories()` still returns `(full, summary)`, but its remaining observer
callers discard `full`; `extract_session_insights()` is now only called by a manual script.
See [upstream issue #284](https://gitlab.com/ghavenga/opencode-memory/-/work_items/284) for the
bisect and linked source references. Do not patch the editable local install: installer upgrades
would overwrite it. Wait for the upstream fix or contribute it as an MR.

Do not replay historical transcripts through Tier 1's deterministic salience gate. A 150-session
sample retained 9.18 whole turns per session at its normal threshold (about 39,000 across the
history). Increasing the threshold selected longer transcript blobs rather than more precise
claims: median retained length grew from 210 characters at one signal to 3,505 at three. Tier 1
is for short-lived, in-session recall; use selective LLM extraction for historical knowledge.

`context_injections` is a deprecated table retained for migrations. Current plugin activity is
recorded in `context_events`; inspect its `boot`, `user_injection`, and `thinking_injection`
event types when measuring whether a memory reaches an agent's context window.

## Tier 1 Project Attribution

The plugin deliberately sends `project = "auto"` with every Tier 1 capture and includes the
session working directory so the server can resolve the Git remote. In upstream `server.py`,
`_capture_turn()` initially checked only `if not project`, leaving the truthy sentinel string in
the `memories.project` column. This made scoped recall silently omit every Tier 1 memory and
would also propagate `auto` into Tier 2 spans and derived concepts.

The local editable install has the canonical guard at both `_capture_turn()` and `_remember()`:

```python
if project == "auto" or project is None:
    project = _detect_current_project(working_directory)
```

On 2026-08-07, all existing `project = 'auto'` rows were restored from exact verbatim-turn
matches in `~/.local/share/opencode/opencode.db`: 37 to `gitlab-org/gitlab`, four to the prompt
library project, and 24 to `NULL` for home-directory sessions without a Git remote. A snapshot
including `memory.db`, `memory.db-wal`, and `memory.db-shm` is in
`~/.local/share/opencode-memory/backups/` before the migration. A direct capture from the local
upstream checkout then stored `ghavenga/opencode-memory`, proving the forward fix.

The server is a separate LaunchAgent from daemon and worker. After changing this server code,
restart all three to ensure the process listening on port 9824 has reloaded it:

```
launchctl kickstart -k gui/$UID/com.opencode.memory
launchctl kickstart -k gui/$UID/com.opencode.memory.daemon
launchctl kickstart -k gui/$UID/com.opencode.memory.worker
```

The source edit is deliberately local and will be overwritten by an installer upgrade. Keep it
until upstream accepts an equivalent fix; the upstream issue was deferred until this local proof
was complete.

## Tier 2/3 And LLM Isolation

Tier 3 reflection is not ready to enable in normal use. It needs Tier 2 span capture first:
`SessionReflector.reflect()` returns `no_transcript` when `span_turns` is empty, and spans are
only written with `ingestion.tier2_distill = true`. It also only enqueues from the `session_end`
tool, which the bundled plugin does not call. The session registry is agent-driven, not
plugin-driven. Tier 3 was introduced in upstream commit `a9fd1c0` without plugin changes; do not
enable either tier until an explicit session-end trigger and their ongoing per-span LLM cost have
been evaluated.

The README warning against the `opencode` summarizer provider applies to the separate
bulk-ingest subsystem, which is not configured here. It does not apply directly to
`ingestion.llm_extraction`. The underlying risk is mitigated by `[BG] memory-*` session titles:
passive ingestion and Tier 1 capture skip them. This was verified on 2026-08-07 after enabling
LLM analysis: 120 background sessions had produced zero memories traceable to a background
session. Recheck this during the 48-hour review. If a non-MCP provider becomes necessary,
configure a per-purpose `duo` override under `[llm.purpose_overrides]` rather than changing the
global provider mid-trial.

When changing `[ingestion]` watch paths, restart the daemon explicitly:

```
launchctl kickstart -k gui/$UID/com.opencode.memory.daemon
```

`memory-ctl.sh start` does not reload configuration when the HTTP server is already healthy.
After changing a brain watch path, backfill it once with:

```
~/.local/share/opencode-memory-install/.venv/bin/python \
  -m opencode_memory.cli ingest \
  ~/Developer/gitlab.com/pedropombeiro/weekly-log/brain --recursive
```

Memory source paths were migrated on 2026-08-06 from the former
`gitlab-org/growth/ai/weekly-log-template` clone to the personal
`pedropombeiro/weekly-log` clone. The migration changes provenance only; it neither creates
nor re-embeds memories.

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
