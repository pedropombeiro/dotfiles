# Mise

Runtime versions and CLI tools management.

## Configuration

**Main config**: `~/.config/mise/config.toml` — a YADM alt symlink. On this machine it
resolves to `config.toml##default`; on QTS to the `distro.qts` alt.

Additional layered configs live in `~/.config/mise/conf.d/` (`global.toml`, `tasks.toml`,
`tools.personal.toml`, `tools.work.toml`, `tools.linux.toml`, ...). The YADM-selected
`~/.config/mise/miserc.toml` enables the machine-class environment and mise's automatic
platform environments. File-based tasks live in `~/.config/mise/tasks/`.

`conf.d/bootstrap.toml` declares repositories and user LaunchAgents that mise
converges during YADM bootstrap. Bootstrap scripts invoke explicit `--only`
scopes. Do not run bare `mise bootstrap`, because mise's dotfile, macOS default,
and user configuration overlap existing YADM workflows.

## Tool Categories

### Language Runtimes

```toml
[tools]
python = "3.14"
go = "1.25.6"
rust = "1.93.0"
node = "23.7.0"
```

### CLI Tools

```toml
[tools]
bat = "latest"
fd = "latest"
ripgrep = "latest"
```

### Python Tools (via pipx backend)

```toml
[tools]
"pipx:pre-commit" = "latest"
"pipx:vale" = "latest"
```

### Backend Caveats (pipx / uv)

The `pipx:` and `uv:` mise backends shell out to the real `pipx` / `uv` binary
at install time. If a project uses these backends, the backend tool itself must
also be present in the same mise context — otherwise install fails with:

```
pipx may be required but was not found.
Failed to install pipx:<pkg>: pipx install <pkg>==<ver>: No such file or directory
```

This bites most often in CI when `MISE_TOOLS` is an explicit allow-list. Always
include `pipx` (or `uv`) alongside any `pipx:foo` / `uv:foo` entry.

Note: the `uv:` backend is only available as a built-in in newer mise versions.
Check `mise backends` to confirm it is listed before using it; otherwise fall
back to `pipx:` with an explicit `pipx` entry in `MISE_TOOLS`.

### Backend Caveats (gem)

The `gem:` backend falls back to the **system** `gem` when no mise-managed Ruby
resolves. On macOS that is Ruby 2.6.10, so failures surface as unrelated gem
dependency errors rather than "Ruby not installed":

```
ERROR:  Error installing ruby-lsp:
	prism requires Ruby version >= 2.7.0. The current ruby version is 2.6.10.210.
```

When a `gem:` tool fails on a version constraint, run `mise ls ruby` first and
look for `(missing)`. The gem error is a symptom; the missing runtime is the cause.

### Ruby Plugin Scope (work machine)

`~/gitlab-development-kit/gitlab/mise.toml` registers GitLab's
[asdf-gitlab-ruby](https://gitlab.com/gitlab-org/quality/tooling/asdf-gitlab-ruby)
plugin for `ruby`. Plugins register **machine-wide**, so this governs `ruby`
everywhere on the work machine, not just inside the GDK. Confirm with
`mise plugins ls`; `mise registry ruby` still reports `core:ruby`, which is
misleading.

Two consequences:

- The plugin only fetches precompiled binaries when `USE_PRECOMPILED_RUBY=true`,
  which the GDK sets in its own `mise.toml`. Outside the GDK it always compiles
  from source, which is slow, especially with `jobs = 1`.
- It can only install versions listed in the plugin's `versions.txt`. Check
  before pinning:

  ```bash
  curl -fsSL https://gitlab.com/gitlab-org/quality/tooling/asdf-gitlab-ruby/-/raw/main/versions.txt \
    | grep ',macos,arm64,'
  ```

Because of this, `ruby` is declared per class rather than in `config.toml`:
`conf.d/tools.work.toml` pins the newest version in the manifest, while
`conf.d/tools.personal.toml` uses `core:ruby` and can track upstream.
A Renovate rule in `.renovaterc.json` holds the work pin.

### Config Precedence

`~/.config/mise/config.toml` **outranks** `~/.config/mise/conf.d/*`. When a tool
is declared in both, editing the `conf.d` copy has no effect. Use
`mise ls <tool>` to see which file mise credits for the active version:

```
ruby  3.4.9   ~/.config/mise/conf.d/tools.work.toml  3.4.9
```

To vary a tool per machine class, remove it from `config.toml` entirely and
declare it only in the environment-specific `conf.d` files. Leaving it in both
means the shared value always wins.

### Config Environments

`~/.config/mise/miserc.toml` is a YADM alternative that enables `env_conf_d`,
`auto_env`, and the explicit `personal`, `work`, or `qts` environment. Environment
fragments use names such as `tools.personal.toml`, `tools.work.toml`, and
`tools.qts.toml`; platform fragments such as `tools.linux.toml` load through
`auto_env`.

The explicit environment has higher precedence than automatic platform
environments. On QTS, `tools.linux.toml` loads first and `tools.qts.toml` then
overrides incompatible runtime versions and libc settings.

These early settings do not appear in `mise settings`; verify them through
`mise config ls` and the resulting toolset instead.

### GitHub Credentials

Use `settings.github.credential_command = "gh auth token"` in the global config
instead of sourcing a script that exports `MISE_GITHUB_TOKEN`. The credential
command runs only when mise needs GitHub authentication, while `env._.source`
runs during every environment refresh. mise ignores `github.credential_command`
from project config for security reasons.

The default `github.gh_cli_tokens = true` is not sufficient when `gh` stores its
token in the macOS keychain and leaves no `oauth_token` value in `hosts.yml`.

### Backend Caveats (npm / aube)

Since mise 2026.8.x, `npm:` tools install through mise's embedded `aube`
package manager, which applies supply-chain gates that npm does not. In
non-interactive contexts (`mise run` auto-install, CI) aube's confirmation
prompts cannot be answered, so they surface as an opaque abort:

```
Failed to install npm:<pkg>@latest: aube install failed: user aborted `mise add <pkg>`
```

To see the real prompt, force a TTY:

```bash
script -qfec "mise install npm:<pkg>@latest" /dev/null
```

Fix with the narrowly scoped tool option, never a global override:

| aube gate                            | Symptom                                           | Tool option                           |
| ------------------------------------ | ------------------------------------------------- | ------------------------------------- |
| `lowDownloadThreshold` (1000 weekly) | "looks suspicious: N downloads last week"         | `allow_low_downloads = true`          |
| `trustPolicy=no-downgrade`           | version lost provenance versus an earlier release | `trust_policy_excludes = ["pkg@ver"]` |
| build-script approval                | dependency needs a lifecycle script               | `allow_builds = ["esbuild"]`          |

Do **not** set `npm.shell_out=true` or `lowDownloadThreshold: 0`: both disable
aube's checks for every package. Prefer version-scoped exceptions over bare
package names, and record why in a comment (see `npm:renovate`).

#### Warnings that are expected, not misconfiguration

Two aube install warnings have no per-tool fix and should be left alone:

- `Unsupported engine <pkg>: wanted node ^X, got Y`. aube checks the package's
  `engines.node` against the **global** mise node (`node = "latest"`). It is a
  warning only (`engineStrict` defaults to false). There is no per-tool node pin
  for the npm backend: `install_env` is not applied on the embedded-aube install
  path, and aube's `nodeVersion` is validation-only and lives in an `.npmrc` that
  mise owns and rewrites. If a specific step genuinely needs a matching runtime,
  scope it at the call site with `mise x node@24 npm:<pkg> -- <cmd>`.
- `N transitive packages have deprecation warnings`. aube's
  `deprecationWarnings` defaults to `direct`, which prints a count for
  transitives. These belong to the package's own dependency tree, so there is
  nothing to fix locally, and the only levers (`AUBE_DEPRECATION_WARNINGS`,
  `allowedDeprecatedVersions`) are global or in the mise-owned `.npmrc`.

Conversely, `RE2 not usable, falling back to RegExp` from `npm:renovate` **is**
actionable: `re2` is an optional native dep whose build aube denies by default,
so it needs `allow_builds = ["re2"]`.

### Backend Caveats (pipx git sources)

For `pipx:git+https://github.com/<owner>/<repo>.git`, mise resolves versions
from that repo's **GitHub releases only**, never tags and never branches. A repo
with tags but no releases lists zero versions.

A branch pin therefore makes every `mise upgrade` warn:

```
Error getting latest version for pipx:git+https://…: no latest version found
```

The pin still installs correctly. Only "what is latest?" fails. Fixes, best
first: cut a GitHub release in the fork and pin that tag, or pass
`mise upgrade --exclude '<full backend spec>'`. The short tool name does not
match, and `minimum_release_age_excludes` does not help, since it is a different
code path.

A newly published release stays hidden for 24h under the default
`minimum_release_age`, so the same warning persists until the window passes.
Confirm that is the only cause with `MISE_MINIMUM_RELEASE_AGE=0s mise upgrade --dry-run`.

When pinning a fork tag, avoid a bare upstream-shaped version. A suffix such as
`v0.134.0-whole-ride.1` keeps the tag from colliding with a future upstream
`v0.134.0`. Note that semver reads that suffix as a _prerelease_ which sorts
**below** plain `0.134.0`, so Renovate ranks any upstream tag higher and would
silently drop the fork's patches. Disable the package in `~/.renovaterc.json` and
re-tag by hand after rebasing onto upstream (see
`pedropombeiro/gopro-dashboard-overlay`).

## QNAP/QTS Compatibility

The QTS environment has glibc 2.21 limitations. Distro-specific pins live in
`~/.config/mise/conf.d/tools.qts.toml`.

- **Python**: QTS has no musl loader, so precompiled binaries must use the gnu variant.
  Use `x86_64` (not `x86_64_v2`) for `precompiled_arch` — the v2 build embeds
  `-march=x86-64-v2` in Python's sysconfig CFLAGS, which breaks C extension compilation
  with the system GCC 8.4 (only GCC 11+ supports that flag). Python and all Python CLI
  tools are fully mise-managed — opkg python3/python3-pip are **not** installed.
- **Node**: Uses unofficial builds with glibc-217 flavor.

```toml
[settings.python]
precompiled_arch = "x86_64"
precompiled_os = "unknown-linux-gnu"

[settings.node]
mirror_url = "https://unofficial-builds.nodejs.org/download/release/"
flavor = "glibc-217"

[tools]
python = "3.14"
node = "23.7.0"
```

## Common Operations

```bash
mise install          # Install tools from config
mise use <tool>       # Add a new tool
mise upgrade          # Update all tools
mise list             # List installed tools
mise outdated         # Check for outdated tools
```

## Task Usage Headers

For file-based tasks (e.g. `.mise/tasks/*`), define arguments using `#USAGE` directives.
`#MISE usage=...` is not supported and will cause `mise` to reject the task file.

Example:

```bash
#!/usr/bin/env bash
#MISE description="Build with sourcemaps"
#USAGE arg "<package>" help="Package to build"
```

## Task Semantics

- `depends = [...]` runs the listed tasks **in parallel**. To force sequential
  execution, use a `run` array instead — its entries run in order.
- `sources` / `outputs` enable caching: mise skips the task when every `sources`
  glob is older than every `outputs` glob.
- `run_windows` overrides `run` on Windows.

## Tool Postinstall Hooks

Use a tool-level `postinstall` option for setup that belongs to one installed
tool. The hook runs only after that tool is installed or reinstalled and receives
`MISE_TOOL_NAME`, `MISE_TOOL_VERSION`, and `MISE_TOOL_INSTALL_PATH`. This is
preferable to a global `[hooks].postinstall` script that inspects
`MISE_INSTALLED_TOOLS`.

Safe mode (`MISE_SAFE=1`) blocks tool-level postinstall hooks because they execute
configuration-provided code.

## Renovate Integration

Tools are auto-updated by Renovate bot via `~/.renovaterc.json`. Check PRs for pending updates before manual upgrades.

## Guidelines

- Prefer mise-managed tools over system packages
- Use `latest` version when appropriate
- Document QNAP compatibility issues
- Use `pipx:` backend for Python CLI tools; always include `pipx` itself in `MISE_TOOLS` when used in CI
- Before using `uv:` backend, confirm it appears in `mise backends` — it requires a newer mise version
- For `npm:` install failures, identify which aube gate fired before adding an exception; use the per-tool option, not a global setting
- When a `gem:` tool fails on a Ruby version constraint, check `mise ls ruby` for `(missing)` before debugging the gem
- Before bumping `ruby` on the work machine, confirm the version appears in the asdf-gitlab-ruby `versions.txt`
- To vary a tool per machine class, declare it only in the matching environment fragment, never alongside an entry in `config.toml`
- Use `settings.github.credential_command` rather than `env._.source` for lazy GitHub authentication
- Attach install-specific setup to the relevant tool with `postinstall`, not a global postinstall hook
