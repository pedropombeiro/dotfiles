# OpenCode Memory

Long-term semantic memory system for OpenCode sessions (project: `opencode-memory`,
upstream now brands it GHMEM). Runs as a local MCP server
(`memory`, `http://localhost:9824/mcp`) plus a plugin. Full docs:
`opencode-memory/BOOTSTRAP.md`.

> **Two very different deployments.** Everything up to "NAS (QTS) Deployment" describes
> the **work Mac**: the _Python_ runtime installed to
> `~/.local/share/opencode-memory-install/` via `setup.sh`, under launchd. The NAS runs
> the _Rust_ runtime built from source, with no launchd, no shim, and different paths.
> Do not apply Mac instructions to the NAS or vice versa.

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

- On this NAS's Rust HTTP server, before working on an MR/issue/epic, call
  `get_context(entity_ref)` to get history.
- Use `claim_item()` before making changes to prevent conflicts.
- Store important decisions, blockers, and procedures with `remember()`.
- Release claimed items when done with `release_item()`.
- Use `recall(query)` to search for relevant context.

The Mac stdio shim consolidates the full tool surface behind `memory(action=...)`.
The NAS Rust runtime intentionally does not implement that shim and exposes its
bare tools directly; see [MCP wiring: URL form, not the shim](#mcp-wiring-url-form-not-the-shim).

Those five are the common-path tools, **not** the whole surface: the Rust server
advertises 86 tools. Confirm anything beyond them (`edit_memory`, `archive_memory`,
`set_reminder`, `resolve_blocker`, `get_by_id`, the `queue_*` and `graph_*` families,
etc.) with `lazy-mcp_list_commands` before use. Do not extrapolate names from the Mac
Python shim: plausible names such as `update_memory` and `get_memory` do not exist on
the NAS; use `edit_memory` and `get_by_id` instead.

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
It currently remains `false` to avoid those costs.

The periodic `KnowledgeExtraction` job currently has no passive-ingestion input: it queries
`conversation` memories, while the daemon calls `extract_session_summary()` and stores only
`conversation_summary`. Do not enable `llm_extraction` expecting it to mine normal sessions
until upstream fixes that ingestion mismatch.

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

## NAS (QTS) Deployment

The NAS runs a **different runtime to the Mac**: the Rust implementation from the
repo's `rust/` subtree, built from source and installed to `~/.local/bin/memory`.
Nothing here uses `setup.sh`, launchd, systemd, Docker, or the Python package.

|               | Work Mac                                               | NAS (QTS)                                  |
| ------------- | ------------------------------------------------------ | ------------------------------------------ |
| Runtime       | Python (`opencode-semantic-memory`)                    | Rust (`memory` binary)                     |
| Install       | `setup.sh` → `~/.local/share/opencode-memory-install/` | built from `~/opt/opencode-memory`         |
| Supervision   | launchd (3 agents)                                     | RunLast at boot + `*/5` cron watchdog      |
| MCP transport | local shim `memory-mcp.sh`                             | **remote URL** `http://localhost:9824/mcp` |
| Config alt    | `##class.Work`                                         | `##distro.qts`                             |
| Memory corpus | work store                                             | independent — deliberately not synced      |

### Why Rust and not Python

The Python runtime needs `lancedb` + `torch`, which only publish
`manylinux_2_28` wheels. This NAS is **glibc 2.21**, so they can never be installed
and building them from source is not realistic. The Rust runtime uses `candle`
instead of `torch` and compiles against the host toolchain.

It is also far lighter: **~340-380MB RSS** across all three processes (measured),
versus the ~2GB the Python/torch stack holds resident.

### Building

```
/share/Container/scripts/build-opencode-memory.sh          # build if needed
/share/Container/scripts/build-opencode-memory.sh --force  # force rebuild
```

That script is the single source of truth. It pins an upstream **commit** (there are
no release tags — the releases API returns `[]`), warns when the pin falls behind
`origin/master`, and skips work when the installed binary already matches.

- A cold build is **~105 minutes** (845 crates including all of `datafusion` and
  `candle`, on a 4-core Celeron J4125).
- `--release` is mandatory: upstream notes embeddings run ~20× slower in debug.
- `yadm bootstrap` deliberately does **not** build. `975-verify-opencode-memory.sh`
  only reports whether the binary exists and prints the build command.

### Build prerequisites (the non-obvious ones)

Both are declared in `~/.config/mise/conf.d/distro-specific.toml`:

- **`protoc`** — `lance`/`prost-build` shell out to it. Entware ships protobuf
  _libraries_ but no `protoc` binary.
- **`sccache`** — upstream's `rust/.cargo/config.toml` hardcodes
  `rustc-wrapper = "sccache"`, so the build fails outright when it is missing, not
  merely uncached.

### The glibc 2.25 proc-macro trap

This NAS has **two glibcs**:

|         | Path                 | Version                                    |
| ------- | -------------------- | ------------------------------------------ |
| System  | `/lib/libc.so.6`     | 2.21 — `rustc` itself runs under this      |
| Entware | `/opt/lib/libc.so.6` | 2.27 — the only available `gcc` links here |

Rust's libstd carries a _weak undefined_ `getrandom` reference. The Entware linker
binds it to `getrandom@GLIBC_2.25`. When `rustc` then `dlopen()`s a proc-macro `.so`
into its own process — running under the 2.21 loader — the load fails:

```
libserde_derive-*.so: /lib/libc.so.6: version `GLIBC_2.25' not found
```

This breaks **any** crate using derive macros, so it is a general limitation of
building Rust on this host, not something specific to this project.

**Fix:** link `/share/Container/scripts/lib/qts-getrandom-shim.c` (a direct syscall
implementation) into every crate, with `-Wl,-Bsymbolic` so the local definition wins
over the versioned glibc one:

```
RUSTFLAGS="-C link-args=<shim>.o -C link-args=-Wl,-Bsymbolic"
```

No upstream patching is needed, so there is no fork to maintain. The build script
handles this automatically.

**Consequence:** the resulting binary uses Entware's loader
(`/opt/lib/ld-linux-x86-64.so.2`) and needs glibc 2.27, so it **cannot start before
Entware is mounted**. The ensure script checks for this explicitly.

### Startup and supervision

There is no systemd on QTS, and BusyBox crond (1.33.1) has **no `@reboot`** — verified
by inspecting the binary's strings. Two mechanisms cover the two failure modes:

| Mechanism                                       | Covers                                                   |
| ----------------------------------------------- | -------------------------------------------------------- |
| `scripts/runlast/95-start-opencode-memory.sh`   | boot (RunLast waits for QTS to finish starting packages) |
| `*/5` line in `scripts/runlast/10-user.crontab` | crashes (RunLast fires only once per boot)               |

Both call the same idempotent `scripts/cron.d/ensure-opencode-memory.sh`, which starts
only the processes that are actually missing and annotates Grafana when it does.

Two host quirks that shape that script:

- **There is no `nohup` on this NAS.** Use `setsid` alone to detach.
- **RunLast's `RunAndLog` captures output with `stdout=$(eval ...)`**, which blocks
  until the pipe closes. A child inheriting stdout would hang the entire boot
  sequence, so every process is started with stdin from `/dev/null` and
  stdout/stderr redirected to files under `~/.local/state/opencode-memory/`.

### MCP wiring: URL form, not the shim

`servers.json##distro.qts` points lazy-mcp at `http://localhost:9824/mcp` directly.
This **contradicts the Mac guidance above**, and deliberately so: the Rust runtime
does not implement the stdio shim at all (`rust/crates/memory-server/src/workflow/mod.rs`
— "Shim not ported"). It serves MCP over HTTP and appends the `workflow` tool to its
own advertised list, so the URL form is the intended access path here.

Routing through lazy-mcp is **mandatory, not an optimisation**: the Rust server
advertises **86 tools** with no `memory(action=...)` consolidation, which would
otherwise land in every session's context window.

`GITLAB_TOKEN` is intentionally **unset**. The Rust server reads it from its own
process environment, so GitLab enrichment, spider, and watchers stay off; plain memory
tools are unaffected.

### Health check quirk

`/health` returns **503 with `status: degraded`** while the embedding queue is backed
up — not an error. On first start the daemon ingests the whole existing
`opencode.db` (300+ memories), which took ~2.5 minutes to drain. Check the body
rather than the status code:

```
python3 -c "import urllib.request,json;print(urllib.request.urlopen('http://127.0.0.1:9824/health').read())"
```

(`curl` is denied by the OpenCode permission rules; use Python or check the process
list instead.)

### Backups

`config/borg/borgmatic.d/homes.yml` covers `~/opt` and
`~/.local/share/opencode-memory`, excluding regenerable output (`rust/target` ~2.8GB,
`node_modules` ~84MB, and the LanceDB `vectors/`, which are re-embedded from
`memory.db`).

**Do not add a SQLite dump hook, and never exclude the `-wal` file.** The database is
in WAL mode; backing up `memory.db` with its `-wal`/`-shm` siblings restores exactly
like a crash recovery. This was verified by copying all three during 57 concurrent
writes: `integrity_check` passed and the result was a consistent point-in-time
snapshot. Conversely, backing up `memory.db` _alone_ silently loses the newest
memories — the WAL was 4.3MB against a 1.2MB main DB, and a test copy dropped 3
recent rows. Backups also run at 04:00, when nothing is writing.
