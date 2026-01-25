# Mise

Runtime versions and CLI tools management.

## Configuration

**Main config**: `~/.config/mise/config.toml##distro.qts`

## Tool Categories

### Language Runtimes

```toml
[tools]
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

The QTS environment has glibc 2.17 limitations:

```toml
[tools.node]
version = "23.7.0"
postinstall = "corepack enable"
[tools.node.options]
flavor = "glibc-217"
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
