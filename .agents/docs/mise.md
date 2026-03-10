# Mise

Runtime versions and CLI tools management.

## Configuration

**Main config**: `~/.config/mise/config.toml##distro.qts`

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

## QNAP/QTS Compatibility

The QTS environment has glibc 2.21 limitations. Distro-specific pins live in
`~/.config/mise/conf.d/distro-specific.toml##os.Linux,distro.qts`.

- **Python**: QTS has no musl loader, so precompiled binaries must use the gnu variant.
  The CPU (Celeron J4125) supports x86_64_v2 but not v3. Python and all Python CLI
  tools are fully mise-managed — opkg python3/python3-pip are **not** installed.
- **Node**: Uses unofficial builds with glibc-217 flavor.

```toml
[settings.python]
precompiled_arch = "x86_64_v2"
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

## Renovate Integration

Tools are auto-updated by Renovate bot via `~/.renovaterc.json`. Check PRs for pending updates before manual upgrades.

## Guidelines

- Prefer mise-managed tools over system packages
- Use `latest` version when appropriate
- Document QNAP compatibility issues
- Use pipx backend for Python CLI tools
