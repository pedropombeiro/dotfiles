# OpenCode Policies

## Skill loading

- Shared skills live in `~/.agents/skills`. OpenCode's global `skills` directory
  links there. OpenCode also discovers `~/.claude/skills` automatically.
- Work-only skills live in `~/.agents/skills.work`. Only
  `opencode.json##class.Work` adds that directory through `skills`.
- `AGENTS.md##template` adds the instruction to read `~/.agents/docs/work.md`
  only on Work machines, through a `{% if yadm.class == "Work" %}` block. OpenCode 2
  accepts the `instructions` config field but does not load its entries.
- Keep work-only skills out of all shared discovery directories. The
  `sync-work-skills.zsh` helper relocates legacy installations, creates available
  work-repository links on Work machines, and runs from the relink workflow.
- `~/.config/yadm/scripts/work-skills.zsh` is the single list of work-only skill
  names, shared by `sync-work-skills.zsh` and the `run-checks` lock-file check.
- Use `~/.config/yadm/scripts/sync-work-skills.zsh --update` for upstream skill
  updates. It skips work-only updates on personal machines and relocates snapshots
  recreated by the installer. The ClickHouse snapshot and its lock entry remain
  managed by `npx skills`.
- `handoff` is a locally maintained, platform-neutral skill tracked by YADM.
  Do not replace it with a link to the work repository.

The background service reloads config from watched config directories
automatically; run `opencode reload` to force it, and `opencode service restart`
after changing environment variables or unwatched local plugin dependencies.
`opencode debug config` lists each config source with its normalized content, not
the merged result. Project-local skills remain scoped to their repository.
Permission `allow` entries do not form an allowlist.

## Permission audits

Before recommending a new permission rule from session history, confirm that the
call actually prompted. A tool name without its own rule does not prove a prompt:

- Wrapper tools check their own action. Every `lazy-mcp` downstream call checks
  `lazy-mcp_invoke_command` with resource `*`, so a rule such as
  `gitlab_get_merge_request` has no effect on a call routed through `lazy-mcp`.
- `~/.config/opencode/plugins/lazy-mcp-permissions.js` adds per-command checks for
  `lazy-mcp` calls. It re-evaluates the agent's `lazy-mcp_invoke_command` rules
  against the resource `server/command`, so allow a read-only command in
  `opencode.json` with a rule such as `"resource": "gitlab/get_*"`, placed after
  the `"resource": "*"` ask rule. Add it to both alternates when both machines
  have the server. **Allow always** saves an approval for the whole wrapper, which
  the plugin ignores, so per-command approvals belong in `opencode.json`.
- Saved **Allow always** approvals live in the `permission` table of
  `~/.local/share/opencode/opencode.db` and apply on top of the config.
- Session history stores calls in `session_message` (V2) and `part` (legacy). The
  same calls can appear in both, so count from one table.

## Secret Protection

`~/.config/opencode/plugins/env-protection.js` is a plain tracked file, so it is active on
every machine. It blocks direct access to configured credential files, redacts values read
through shell commands, detects common structured tokens, and scrubs replayed message
history. It refuses any tool call whose input contains a literal structured secret, except
`read`, `grep`, and `glob`, which stay local. That covers file writes, MCP calls through
`lazy-mcp`, web search and fetch, and subagent prompts. Shell commands are checked only
when they print or write text (`echo`, `printf`, `tee`, heredocs), because commands such as
`curl -H` can legitimately pass a token.

Home-directory path rules are `permissions` entries with a `read` or `edit` action, for
example `{ "action": "read", "resource": "~/.ssh/*", "effect": "deny" }`. OpenCode expands
a leading `~` for `read`, `edit`, and `external_directory` resources, but not for `shell`,
so these rules do not stop `cat ~/.ssh/...`. A `*` in a rule also matches nested paths.
Reads under `~/.config/opencode/` ask instead of being denied, so an agent can inspect
config or skills with approval. `opencode run` rejects
such reads automatically.

Redaction markers are transit-only. The plugin blocks rather than rewrites file-write content
that contains a structured secret, so it cannot persist a marker over the original value.

## OpenCode versions

Every machine runs OpenCode 2. Both `opencode.json` alternates use the native V2 format:
an ordered `permissions` array (last match wins), `providers`, `mcp.servers`, and
`agents.title.model`. `enabled_providers` stays in V1 syntax until provider policies
leave `experimental`. When migrating another config, compare `opencode debug config`
output for the old and new files, loaded as project configs from scratch directories.
The NAS (`distro.qts`) gets OpenCode 2 from the `opencode-legacy-glibc` build and uses
the `##default` config alternates. Do not add
OpenCode 1 fallbacks (`plugin`, `tui.json`, `server()` plugin entrypoints, `--pure`).

## Plugins

OpenCode 2 splits plugins by where they run:

- Server plugins go in `plugins` in `opencode.json`. They run in the background service,
  which may not share the terminal's environment.
- Terminal (CLI) plugins go in `plugins` in `cli.base.json` (see
  [Terminal config](#terminal-config)). Anything that talks to the terminal or tmux
  (`opencode-terminal-progress`, `opencode-tmux-indicator`) belongs here.
- Local plugins are files in `~/.config/opencode/plugins/` that default-export
  `{ id, setup(ctx) }`. The shell tool is named `shell`, and file tools take `path`.
  Tool hooks also fire for tools called through Code Mode (`execute`), with the inner
  tool's name.

### Explicitly loaded plugin directories

OpenCode discovers every plugin under `~/.config/opencode/plugins/` and can't pass it
options. A plugin directory that needs options, or that a config alternate should load
only on some machines, lives in `~/.config/opencode/local-plugins/` instead. That folder
is outside the discovery paths, so a plugin there loads only through a path entry:

- `local-plugins/server/<name>/`: listed in `plugins` in `opencode.json` as
  `./local-plugins/server/<name>`. Its `index.ts` runs in the background service, and an
  optional `tui.tsx` loads in the CLI automatically.
- `local-plugins/tui/<name>/`: listed in `plugins` in `cli.base.json` as
  `./local-plugins/tui/<name>`. It has only `tui.tsx`, which runs in the CLI.

OpenCode resolves these relative paths against `~/.config/opencode/`. Local `.tsx`
plugins can import `solid-js`, `@opentui/solid`, and `@opencode/plugin/tui` without a
`package.json`; OpenCode provides them at runtime. Run a local plugin's tests with
`mise exec bun@1.3.10 -- bun test` from its directory.

Each local plugin documents its behavior, options, and tests in its own README:

- [`session-metrics`](../../.config/opencode/local-plugins/tui/session-metrics/README.md):
  shows compactions, reported cache reuse, and recorded session/descendant timing in
  the sidebar, with a width-aware footer fallback and a details panel.
- [`permission-mode`](../../.config/opencode/local-plugins/tui/permission-mode/README.md):
  toggles the global permission preference with Shift+Tab.
- [`queue-command`](../../.config/opencode/local-plugins/tui/queue-command/README.md):
  adds `/queue <message>`, which queues a message for the current session instead of
  sending it right away.
- [`session-open`](../../.config/opencode/local-plugins/server/session-open/README.md):
  adds the `open_session` tool, which focuses a past session of the current project.
- [`otel-status`](../../.config/opencode/local-plugins/server/otel-status/README.md):
  shows in the CLI footer whether the collector accepts OTLP requests.

### Plugins meant for publishing

Some local plugins are trials of plugins that will be published from
[`opencode-plugins`](https://github.com/pedropombeiro/opencode-plugins). Keep their agent
guidance, tool descriptions, defaults, and READMEs generic, so they make sense to users
outside GitLab and outside Pedro's workflows. Describe behavior that any workflow fits,
such as "set every PR/MR the user asks to work on", and leave the workflow-specific part to
the user's request or a skill. For example, the user asks to review the MRs that a recurring
job created, and the agent finds them, then sets them as targets. Never name a
company-specific workflow, project, or schedule in the plugin.

The same applies to plugins published from there. For example,
[`opencode-forgekeeper`](https://github.com/pedropombeiro/opencode-plugins/tree/main/packages/forgekeeper)
started as a local trial. It adds `set_session_target`, prefixes session titles with their
issues and PRs/MRs, shows the PR/MR status in the CLI footer, and notifies the agent about
review feedback. Its server keeps the plugin and RPC ID `opencode-forge-session-title`, so
never load it alongside `opencode-forge-session-title`.

### Editing local plugins

The background service reloads a local plugin as soon as its file changes, so every
intermediate state of a multi-step edit goes live. A tool hook that throws blocks
every tool call, including the edits that would fix it.

- Change a local plugin in one complete write, never as a series of edits.
- Test the new version before writing it: load a copy with `node`, appending
  `export { check }` (or the relevant function) to the source, and run it against
  test cases. Build test inputs such as fake tokens or `rm -rf` at runtime, so that
  the live plugins don't block the test command itself.
- If an agent is locked out, fix or revert the file from a terminal, for example
  with `yadm checkout -- ~/.config/opencode/plugins/<plugin>.js`.

## Terminal config

OpenCode rewrites `~/.config/opencode/cli.json` through a temp file and a rename whenever
a setting changes in the UI, so a yadm alternate symlink there does not survive. The
tracked terminal config (keybinds, scroll, CLI plugins) lives in `cli.base.json##default`
and `cli.base.json##class.Work` instead. `~/.shellrc/rc.d/opencode.sh` exports it as
`OPENCODE_CLI_CONFIG_CONTENT`, which overrides `cli.json` and is never written back.

- `cli.json` is untracked and belongs to OpenCode; it holds UI choices such as theme and
  sidebar. Do not track it or link it.
- Keys set in `cli.base.json` win over the UI, and arrays such as `plugins` replace the
  `cli.json` value instead of merging. Put settings there only when they must be the same
  on every machine.
- Open a new shell after editing `cli.base.json` so the environment variable picks it up.
- `cli.base.json` is JSONC: it carries comments, and OpenCode parses the variable with a
  JSONC parser. Anything else that reads `OPENCODE_CLI_CONFIG_CONTENT` must parse JSONC
  too, as `permission-mode` does. Plain `JSON.parse` fails on the first comment.

Both `cli.base.json` alternates disable `agent.cycle`, so Shift+Tab is free for the
[`permission-mode`](../../.config/opencode/local-plugins/tui/permission-mode/README.md)
plugin. Tab still cycles agents in reverse, and the agent picker remains available.

## Models

`opencode.json` pins per-agent models: `plan` uses Astra and `build` uses Opus 5.5. The
top-level `model` covers other agents, and `agents.title.model` covers maintenance tasks.
Per-agent models take precedence over the top-level `model`, so the `oc` wrapper's inline
`$OPENCODE_MODEL` override (`OPENCODE_CONFIG_CONTENT` with `--standalone`) no longer changes
the model for `plan` or `build`. An explicit `opencode run --model` still wins over the
agent's model, so `oc run` and `git-ai-commit-msg` (`$OPENCODE_COMMIT_MODEL`) are unaffected.

Set the default model in `opencode.json`, not in `$OPENCODE_MODEL`. When the variable is set,
every `oc` launch uses a private server instead of the shared service, and it diverges from
tools that run plain `opencode`, such as `opencode.nvim`. Reserve `$OPENCODE_MODEL` for
per-project overrides in a project's mise config.

## Plugin Version Pinning

npm plugins in `opencode.json` and `cli.base.json` are pinned to exact versions, not `@latest`.

OpenCode installs each entry into `~/.cache/opencode/npm/` and keeps exact versions
pinned. Unpinned entries are only checked for updates; the installed copy does not change
until you run `opencode plugin update`. Pinning makes upgrades explicit and reviewable.

Renovate keeps the pins current via the `opencode npm plugins pinned in opencode.json
(server) and cli.base.json (terminal)` custom manager in `~/.renovaterc.json` (grouped as
`opencode plugins`).

Both alternates of each file must be updated together: `opencode.json##default` and
`opencode.json##class.Work` (and the matching `cli.base.json` pair) are self-contained and not
additive.

To update an unpinned entry, run `opencode plugin update <package>`.

## Telemetry

`@devtheops/opencode-plugin-otel` exports OTLP/HTTP to `https://otel.pombei.ro`, which
Alloy on the NAS routes to Prometheus, Loki, and Tempo. View the data in the **OpenCode**
dashboard on `grafana.pombei.ro`. LAN access uses an IP allowlist. External access
requires per-machine Basic Auth credentials, validated by Traefik before it forwards
OTLP requests to Alloy.

- `opencode.json##default` (Personal and NAS) exports metrics, events, and traces. Traces
  include prompts, model output, tool arguments, and tool output.
- `opencode.json##class.Work` exports metrics only. Traces carry content, and events carry
  commands, paths, and error text, so keep Work content off personal infrastructure.
- `~/.shellrc/rc.d/opencode.sh` sets `OPENCODE_RESOURCE_ATTRIBUTES` to the short host name.
  The background service inherits it from the client that starts the service, so run
  `opencode service restart` from a new shell after changing it. Commands that tmux runs
  directly use a non-interactive shell without it. A service started that way exports
  telemetry with no host, which hides it from host-filtered dashboard panels.
- Alloy drops `session.id` from metrics to keep Prometheus series bounded. Filter by
  session in the dashboard's log and trace panels.
- On macOS, a service started inside tmux can't reach the NAS unless tmux is re-signed.
  The plugin's exports then fail with `EHOSTUNREACH`, and the plugin logs only to the
  console, which OpenCode discards. See
  [Local network access on macOS](tmux.md#local-network-access-on-macos).
- The [`otel-status`](../../.config/opencode/local-plugins/server/otel-status/README.md)
  plugin shows in the CLI footer whether the collector accepts OTLP requests. Its
  `endpoint` and `protocol` options must match the exporter's in both `opencode.json`
  alternates.

### Configure telemetry authentication

`~/.config/mise/conf.d/opencode.toml` reads `OPENCODE_OTLP_HEADERS` from
`~/.config/opencode/otel-headers`, respecting `XDG_CONFIG_HOME`. The credential
file contains one `Authorization=Basic ...` line. Mise marks the variable with
`redact = true` to mask it in captured task output. Treat it as a password because
Base64 encoding does not encrypt credentials. Keep the file outside version control.
If it is missing, mise sets the variable to an empty string and LAN exports still work.

1. Transfer only this machine's `.headers` file over SSH or another secure channel
   from `/share/Container/secrets/otel-clients/` on the NAS. Use `nas.headers` for
   the NAS, `pedros-macbookair.headers` for the personal MacBook Air, or
   `gitlab-macbookpro.headers` for the work MacBook Pro. Save it as
   `~/.config/opencode/otel-headers`. The `.password` file is not needed on the client.
2. Restrict access to the credential:

   ```sh
   chmod 600 ~/.config/opencode/otel-headers
   ```

3. Verify that mise provides the variable without displaying its value:

   ```sh
   mise exec -- sh -c 'test -n "$OPENCODE_OTLP_HEADERS" && echo "OTLP authentication is set"'
   ```

4. Restart the background service from a fresh interactive shell to retain
   `OPENCODE_RESOURCE_ATTRIBUTES` and load the credential:

   ```sh
   mise exec -- opencode service restart
   ```

Repeat the restart after credential rotation. Do not share unfiltered `mise env`
output or dump the service environment because it can expose the credential.
Redaction does not mask `mise env`, `mise exec`, or tasks with `raw = true`.
The work configuration must remain metrics-only.

The `otel-status` probe sends the same headers, so an external `401` from `/otel`
means the service has no credential or a rejected one. Restart the service as
shown above to load a new credential.

## Model availability

`opencode models` includes config-defined entries, including models added only
to override pricing. A listing alone does not confirm backend availability.
Check the provider catalog separately and verify that the replacement works
before changing defaults or retiring an existing model.

For GitLab `duo-chat-*` models, also check `MODEL_MAPPINGS` in the
`gitlab-ai-provider` version selected by the model's npm override, or the
bundled version when no override applies.
Catalog entries and pricing overrides do not register SDK mappings. Missing
mappings cause `Unknown model ID` errors. Workflow models use a separate
discovery path and require separate verification.

## Storage Layout

When inspecting prior OpenCode sessions or tool results, verify the local storage
layout before assuming project-scoped paths from documentation.

- OpenCode data lives under `~/.local/share/opencode/`
- OpenCode docs may describe project-scoped storage under
  `~/.local/share/opencode/project/<project-slug>/storage/`
- Session diffs are stored in `~/.local/share/opencode/storage/session_diff/`
- Tool output is stored in `~/.local/share/opencode/tool-output/`
- Prefer targeted inspection of these known paths over broad recursive searches
  in large directory trees

## Command Chaining Approval

When a chained command is submitted using `&&`, `;`, `||`, or `|`:

- If all subcommands are explicitly allowed, run the chain as-is.
- If any subcommand is unknown or disallowed:
  - Split the chain into individual subcommands.
  - Ask the user to approve each subcommand before execution.
  - Execute only approved subcommands in original order.
  - Stop on first denial unless the user explicitly asks to continue.

### Approval Prompt

Your command contains multiple subcommands. I can run them one by one and ask
you to approve each. Proceed with:

1. `<cmd1>`
2. `<cmd2>`
3. `<cmd3>`
