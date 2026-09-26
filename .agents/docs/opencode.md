# OpenCode Policies

## Skill loading

- Shared skills live in `~/.agents/skills`. OpenCode's global `skills` directory
  links there. OpenCode also discovers `~/.claude/skills` automatically.
- Work-only skills live in `~/.agents/skills.work`. Only
  `opencode.json##class.Work` adds that directory through `skills.paths`.
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

## Secret Protection

`~/.config/opencode/plugins/env-protection.js` is a plain tracked file, so it is active on
every machine. It blocks direct access to configured credential files, redacts values read
through shell commands, detects common structured tokens, and scrubs replayed message
history. It refuses any tool call whose input contains a literal structured secret, except
`read`, `grep`, and `glob`, which stay local. That covers file writes, MCP calls through
`lazy-mcp`, web search and fetch, and subagent prompts. Shell commands are checked only
when they print or write text (`echo`, `printf`, `tee`, heredocs), because commands such as
`curl -H` can legitimately pass a token.

Home-directory path rules belong under `read` and `edit` in `permission`, never as
top-level keys: a top-level key is an action name, so `"~/.ssh/*": "deny"` there matches
nothing. OpenCode expands a leading `~` for `read`, `edit`, and `external_directory`
resources, but not for `shell`, so these rules do not stop `cat ~/.ssh/...`. A `*` in a
rule also matches nested paths. Reads under `~/.config/opencode/` ask instead of being
denied, so an agent can inspect config or skills with approval. `opencode run` rejects
such reads automatically.

Redaction markers are transit-only. The plugin blocks rather than rewrites file-write content
that contains a structured secret, so it cannot persist a marker over the original value.

## OpenCode versions

Every machine runs OpenCode 2. The NAS (`distro.qts`) gets it from the
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

### Editing local plugins

The background service reloads a local plugin as soon as its file changes, so every
intermediate state of a multi-step edit goes live. A tool hook that throws blocks
every tool call, including the edits that would fix it. A half-applied change to
`env-protection.js` once left an agent unable to run any tool until a human repaired
the file.

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
top-level `model` covers other agents, and `small_model` covers maintenance tasks.
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

1. <cmd1>
2. <cmd2>
3. <cmd3>
