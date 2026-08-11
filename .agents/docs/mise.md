# Mise

Runtime versions and CLI tools management.

## Configuration

**Main config**: `~/.config/mise/config.toml` — a YADM alt symlink. On this machine it
resolves to `config.toml##default`; on QTS to the `distro.qts` alt.

Additional layered configs live in `~/.config/mise/conf.d/` (`global.toml`, `tasks.toml`,
`work.toml##class.Work`, `distro-specific.toml##os.Linux,distro.qts`, ...). File-based
tasks live in `~/.config/mise/tasks/`.

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

## QNAP/QTS Compatibility

The QTS environment has glibc 2.21 limitations. Distro-specific pins live in
`~/.config/mise/conf.d/distro-specific.toml##os.Linux,distro.qts`.

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

## Renovate Integration

Tools are auto-updated by Renovate bot via `~/.renovaterc.json`. Check PRs for pending updates before manual upgrades.

## Guidelines

- Prefer mise-managed tools over system packages
- Use `latest` version when appropriate
- Document QNAP compatibility issues
- Use `pipx:` backend for Python CLI tools; always include `pipx` itself in `MISE_TOOLS` when used in CI
- Before using `uv:` backend, confirm it appears in `mise backends` — it requires a newer mise version
