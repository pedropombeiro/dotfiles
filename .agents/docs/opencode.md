# OpenCode Policies

## Secret Protection

Two layers exist:

- `~/.config/opencode/plugins/env-protection.js` — a plain (non-alt) tracked file, so it
  is active on **every** machine.
- secret-guard, bundled with the opencode-memory plugin, loaded via the `plugin` array in
  `opencode.json`.

Both run concurrently on this Work machine. secret-guard redacts matches inline as
`[[SG:learned:<hash>]]` when a file is **read**; the bytes on disk are unchanged. Do not
mistake such a marker for file corruption — check with `od -c` before "fixing" it.

> Earlier revisions of this doc described `env-protection.js##class.Personal` as
> Personal-only and mutually exclusive with opencode-memory. That is no longer how it is
> deployed.

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
