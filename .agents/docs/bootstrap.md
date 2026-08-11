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
    └── 900-999            # Late/optional setup (nginx, tmux, apps, gdk, yadm remote)
```

## Alternate File Syntax

Scripts use YADM alternate files for platform targeting. See
[SCM](scm.md#file-organization) for the suffix list.

## Running Bootstrap

```bash
yadm bootstrap    # Run all bootstrap scripts
mise run dotfiles:install  # Via mise tasks
```

## Script Template

Copy an existing script rather than starting from scratch. They use
`#!/usr/bin/env bash` and source the shared helpers:

```bash
#!/usr/bin/env bash

YADM_SCRIPTS=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../scripts" &>/dev/null && pwd)

# shellcheck source=../scripts/colors.sh
source "${YADM_SCRIPTS}/colors.sh"
```

## Guidelines

- Scripts must be idempotent — bootstrap is re-run on every machine update, not just
  on first install
- Leave numbering gaps so later scripts can be inserted without renumbering

## 1Password Secrets

Use account and vault UUIDs for `op` calls in bootstrap scripts. Vault names such
as `Private` can exist in multiple 1Password accounts on the same machine.
Use the vault UUID in the secret reference and pin the account with `--account`.
Item titles remain readable unless their name is expected to change.
