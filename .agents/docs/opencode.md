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
through shell commands, detects common structured tokens, scrubs replayed message history,
and refuses to persist literal secrets through file, shell, or GitLab write tools.

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
- Terminal (CLI) plugins go in `plugins` in `cli.json`. Anything that talks to the terminal
  or tmux (`opencode-terminal-progress`, `opencode-tmux-indicator`) belongs here.
- Local plugins are files in `~/.config/opencode/plugins/` that default-export
  `{ id, setup(ctx) }`. The shell tool is named `shell`, and file tools take `path`.
  Tool hooks also fire for tools called through Code Mode (`execute`), with the inner
  tool's name.

## Models

`opencode.json` sets one top-level `model` instead of per-agent models. OpenCode 2 has no
interactive `--model` flag, so the `oc` wrapper passes `$OPENCODE_MODEL` through
`OPENCODE_CONFIG_CONTENT` with `--standalone` for the TUI, and `--model` for `oc run`.
Other subcommands run unchanged because `--standalone` is a root-only flag. Inline config
only overrides the top-level `model`, not per-agent models, and only a private server sees
the client's environment.

## Plugin Version Pinning

npm plugins in `opencode.json` and `cli.json` are pinned to exact versions, not `@latest`.

OpenCode installs each entry into `~/.cache/opencode/npm/` and keeps exact versions
pinned. Unpinned entries are only checked for updates; the installed copy does not change
until you run `opencode plugin update`. Pinning makes upgrades explicit and reviewable.

Renovate keeps the pins current via the `opencode npm plugins pinned in opencode.json
(server) and cli.json (terminal)` custom manager in `~/.renovaterc.json` (grouped as
`opencode plugins`).

Both alternates of each file must be updated together — `opencode.json##default` and
`opencode.json##class.Work` (and the matching `cli.json` pair) are self-contained and not
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
