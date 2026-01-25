# Bootstrap

YADM bootstrap scripts for automated system setup.

## Structure

```
~/.config/yadm/
├── bootstrap              # Main entry point
└── bootstrap.d/           # Numbered scripts (run in order, 000-999)
    ├── 000-099            # Early setup (machine class, touchid, launch agents, software install, zinit, firewall, spotlight, mise)
    ├── 100-199            # Configuration (gitconfig, defaults, relink dotfiles)
    ├── 200-499            # (reserved for future use)
    ├── 500-699            # (reserved for future use)
    ├── 700-899            # (reserved for future use)
    └── 900-999            # Late/optional setup (nginx, tmux, mackup, apps, gdk, yadm remote)
```

## Alternate File Syntax

Scripts use YADM alternate files for platform targeting:

| Suffix         | Target             |
| -------------- | ------------------ |
| `##os.Darwin`  | macOS only         |
| `##os.Linux`   | Linux only         |
| `##distro.qts` | QNAP QTS only      |
| `##class.Work` | Work machines only |

## Running Bootstrap

```bash
yadm bootstrap    # Run all bootstrap scripts
just install      # Via justfile
```

## Script Template

```bash
#!/bin/bash
set -euo pipefail

echo "Running: <description>"

# Your setup commands here

echo "Done: <description>"
```

## Guidelines

- Scripts must be idempotent (safe to re-run)
- Use `set -euo pipefail` for safety
- Check for existing installations before installing
- Print progress messages for visibility
- Handle both fresh install and update scenarios
- Keep scripts focused on single responsibility
- Use descriptive numbering (leave gaps for future scripts)
- Make executable: `chmod +x <script>`
- Validate syntax: `bash -n <script>`
