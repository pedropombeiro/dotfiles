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
output for the old and new files, loaded as project configs from scratch directories. The NAS (`distro.qts`) gets it
from the
`opencode-legacy-glibc` build and uses the `##default` config alternates. Do not add
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
- Plugin directories that need options live outside the discovery paths and load
  through a path entry: `local-plugins/<name>/` from `opencode.json` (server, with an
  optional `tui.tsx` that the CLI loads automatically), and `cli-plugins/<name>/` from
  `cli.base.json` (CLI only). Run their tests with `bun test` from the plugin directory.

### Machine-specific CLI plugins

OpenCode discovers every plugin directory under `~/.config/opencode/plugins/`, so a
tracked CLI plugin there loads on every machine. Keep a CLI plugin that should run only
on some machines in `~/.config/opencode/cli-plugins/<name>/`, with its entry point at
`<name>/tui.tsx`, and list it as `./cli-plugins/<name>` in the matching `cli.base.json`
alternate. OpenCode resolves that relative path against `~/.config/opencode/`. Local
`.tsx` plugins can import `solid-js`, `@opentui/solid`, and `@opencode/plugin/tui`
without a `package.json`; OpenCode provides them at runtime.

`cli-plugins/gitlab-mr-status` (Work only) shows an MR's pipeline status, unresolved
thread count, conflicts, and approval in the prompt footer. It picks each session's MR
in this order:

1. The target stored by `set_session_target`, read through the RPC that
   `opencode-forge-session-title` 1.3.0 and later registers.
1. The MR number in the title prefix that plugin writes, such as `[#123, !456]`.
1. The checked-out branch's open MR.

The MR number and pipeline status are links. It adds `/mr-status` and `/mr-open`, and
reads GitLab through `glab api graphql`, so it uses `glab`'s stored login. It caches each
session's status and polls every 2 minutes while an open MR is shown, so switching tabs
reuses cached data until the next poll is due. Run its tests with
`mise exec bun@1.3.10 -- bun test` from the plugin directory.

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
dashboard on `grafana.pombei.ro`. The route accepts requests only from the home network,
so machines elsewhere drop telemetry after the exporter's retries.

- `opencode.json##default` (Personal and NAS) exports metrics, events, and traces. Traces
  include prompts, model output, tool arguments, and tool output.
- `opencode.json##class.Work` exports metrics only. Traces carry content, and events carry
  commands, paths, and error text, so keep Work content off personal infrastructure.
- `~/.shellrc/rc.d/opencode.sh` sets `OPENCODE_RESOURCE_ATTRIBUTES` to the short host name.
  The background service inherits it from the client that starts the service, so run
  `opencode service restart` from a new shell after changing it.
- Alloy drops `session.id` from metrics to keep Prometheus series bounded. Filter by
  session in the dashboard's log and trace panels.
- On macOS, a service started inside tmux can't reach the NAS unless tmux is re-signed.
  The plugin's exports then fail with `EHOSTUNREACH`, and the plugin logs only to the
  console, which OpenCode discards. See
  [Local network access on macOS](tmux.md#local-network-access-on-macos).
- `local-plugins/otel-status` sends an empty OTLP metrics export from the background
  service every 60 seconds (the `intervalSeconds` option) and shows the result in the CLI footer as `● 🔭`, with a green
  dot when the collector accepts it and a red one when not. `/otel` shows the last error
  and runs a check. An accepted empty request doesn't prove that real exports succeed.
  Its `endpoint` and `protocol` options must match the exporter's in both `opencode.json`
  alternates.

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
