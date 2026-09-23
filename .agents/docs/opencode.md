# OpenCode Policies

## Skill loading

- Shared skills live in `~/.agents/skills`. OpenCode's global `skills` directory
  links there. OpenCode also discovers `~/.claude/skills` automatically.
- Work-only skills live in `~/.agents/skills.work`. Only
  `opencode.json##class.Work` adds that directory through `skills.paths` and loads
  `~/.agents/docs/work.md` through `instructions`.
- Keep work-only skills out of all shared discovery directories. The
  `sync-work-skills.zsh` helper relocates legacy installations, creates available
  work-repository links on Work machines, and runs from the relink workflow.
- Use `~/.config/yadm/scripts/sync-work-skills.zsh --update` for upstream skill
  updates. It skips work-only updates on personal machines and relocates snapshots
  recreated by the installer. The ClickHouse snapshot and its lock entry remain
  managed by `npx skills`.
- `handoff` is a locally maintained, platform-neutral skill tracked by YADM.
  Do not replace it with a link to the work repository.

Restart OpenCode after changing skill locations or configuration. Check discovery
outside a project with `opencode --pure debug skill`; project-local skills remain
scoped to their repository. Permission `allow` entries do not form an allowlist.

## Secret Protection

`~/.config/opencode/plugins/env-protection.js` is a plain tracked file, so it is active on
every machine. It blocks direct access to configured credential files, redacts values read
through shell commands, detects common structured tokens, scrubs replayed message history,
and refuses to persist literal secrets through file, shell, or GitLab write tools.

Redaction markers are transit-only. The plugin blocks rather than rewrites file-write content
that contains a structured secret, so it cannot persist a marker over the original value.

## Plugin Version Pinning

npm plugins in `opencode.json` are pinned to exact versions, not `@latest`.

OpenCode resolves each `plugin` entry once and caches the result under
`~/.cache/opencode/packages/<spec>/` with its own `package.json` +
`package-lock.json`. It does **not** re-resolve on restart, so a `@latest` entry
freezes at whatever version was current when first installed and silently never
updates — even across opencode upgrades.

Because the cache key is the spec string, pinning makes upgrades explicit and
self-cache-busting: changing the version creates a new cache entry.

Renovate keeps the pins current via the `opencode npm plugins pinned in
opencode.json` custom manager in `~/.renovaterc.json` (grouped as
`opencode plugins`).

Both alternates must be updated together — `opencode.json##default` and
`opencode.json##class.Work` are self-contained and not additive.

To force a re-resolve of a stale `@latest` entry, delete its cache directory
(use `trash`, not `rm -rf`).

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
