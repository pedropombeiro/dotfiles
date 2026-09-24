# Mise backend troubleshooting

Use this reference for backend selection and installation failures. See
[Mise](mise.md) for configuration precedence and platform policy.

## Python CLI tools

Prefer `pipx:` for Python CLI tools. The `pipx:` and `uv:` backends require the
corresponding executable during installation. Include `pipx` or `uv` alongside
its packages when CI uses an explicit `MISE_TOOLS` allowlist.

If `uv:` is unavailable in `mise backends`, use `pipx:` with an explicit `pipx`
entry. A missing backend executable can surface as `No such file or directory`
during package installation.

### Git sources

For `pipx:git+https://github.com/<owner>/<repo>.git`, mise discovers versions from
GitHub releases, not tags or branches. A branch pin can install successfully
while `mise upgrade` reports `no latest version found`.

Publish a release in the fork and pin its tag, or exclude the full backend spec
with `mise upgrade --exclude '<full backend spec>'`. The short name does not
match; `minimum_release_age_excludes` does not fix missing release discovery.

New releases remain hidden during the default 24-hour minimum release age. Check
whether that is the cause with `MISE_MINIMUM_RELEASE_AGE=0s mise upgrade --dry-run`.

Use a distinct fork tag such as `v0.134.0-whole-ride.1` to avoid collisions with
upstream tags. Semver ranks this suffix below plain `0.134.0`, so disable the
package in `~/.renovaterc.json` to prevent replacement by an upstream release.
Re-tag manually after rebasing the fork.

## Ruby and gems

The `gem:` backend falls back to the system `gem` when no mise-managed Ruby
resolves. If a gem reports an unexpected Ruby version constraint, check
`mise ls ruby` for `(missing)` before debugging its dependencies.

### Ruby backend scope

Installed plugins register machine-wide. GitLab's `asdf-gitlab-ruby` can override
the `ruby` shorthand outside the GDK. Inspect the effective backend with
`mise tool ruby`; `mise registry ruby` does not show the effective selection.

`conf.d/tools.work.toml` selects `ruby = "core:ruby"` under `[tool_alias]` and
sets `[settings.ruby] compile = false`. The built-in backend downloads `jdx/ruby`
binaries and fails promptly when none is available. Personal uses this backend
by default. Both profiles keep version pins in their `tools.*.toml` fragments,
where Renovate can update them without GitLab-manifest restrictions.

The GDK retains its `.tool-versions` selections, but the global backend alias
takes precedence over its `[plugins]` declaration. `USE_PRECOMPILED_RUBY` belongs
to GitLab's plugin and is unnecessary in global configuration.

In mise 2026.9.9, a global backend alias also wins over a project-local alias.
Avoid relying on a local alias to undo this policy. Check exported
`MISE_BACKENDS_RUBY` when selection is unexpected; it overrides aliases.

If a source build stalls at `checking for ruby`, inspect the ruby-build log.
`configure` can invoke the mise shim, which tries to install the same Ruby and
waits for the parent install's lock. Keep global Ruby on the binary backend
rather than adding a hard-coded bootstrap Ruby path.

## npm and aube

mise's embedded aube package manager applies supply chain checks when installing
`npm:` tools. Unanswered confirmation prompts in non-interactive installs can
surface as `aube install failed: user aborted`.

Use the [`run-in-tmux-pane` skill](../skills/run-in-tmux-pane/SKILL.md) to inspect
the prompt in a TTY. If installation needs live input, have the user run it in
their terminal.

Apply a narrowly scoped tool option for the specific check:

| Check                      | Symptom                                       | Tool option                           |
| -------------------------- | --------------------------------------------- | ------------------------------------- |
| `lowDownloadThreshold`     | Package has fewer than 1,000 weekly downloads | `allow_low_downloads = true`          |
| `trustPolicy=no-downgrade` | Version lost provenance                       | `trust_policy_excludes = ["pkg@ver"]` |
| Build-script approval      | Dependency needs a lifecycle script           | `allow_builds = ["esbuild"]`          |

Avoid global overrides such as `npm.shell_out=true` or `lowDownloadThreshold: 0`.
Prefer version-scoped exceptions and record their rationale in a config comment.

### Expected warnings

- `Unsupported engine`: aube checks against the global mise Node version.
  `engineStrict` defaults to false. The embedded-aube path does not apply
  `install_env`, and aube's `nodeVersion` only controls validation in a mise-owned
  `.npmrc`. If execution needs a specific runtime, scope it to the call with
  `mise x node@24 npm:<pkg> -- <cmd>`.
- Transitive deprecation counts: aube's `deprecationWarnings=direct` prints a
  count for transitive dependencies. Fixes belong upstream; local suppression
  uses global settings or the mise-owned `.npmrc`.

`RE2 not usable, falling back to RegExp` from Renovate requires action: aube
denies the optional native dependency's build by default. Add
`allow_builds = ["re2"]` to that tool.
