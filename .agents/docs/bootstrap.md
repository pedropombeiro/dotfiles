# Bootstrap

YADM bootstrap scripts for automated system setup.

## Structure

```
~/.config/yadm/
├── bootstrap              # Main entry point
└── bootstrap.d/           # Numbered scripts (run in order, 000-999)
    ├── 000-099            # Early setup (machine class, touchid, launch agents, software install, zinit, firewall, spotlight, mise, grc-rs rules)
    ├── 100-199            # Configuration (defaults, relink dotfiles)
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

## When bootstrap runs

`yadm bootstrap` provisions a machine. Run it on first install and on demand,
for example after a failure or after adding a script. Updates don't run it:
`update.zsh` runs `mise bootstrap` for packages, repositories, and user
LaunchAgents. See [Mise](mise.md#configuration) for its scope.

Put anything that must stay converged on every update in the mise
`[bootstrap.*]` configuration instead of a `bootstrap.d` script. Keep
`bootstrap.d` for imperative first-run steps, and for macOS state that mise
can't declare:

- System LaunchDaemons in `/Library/LaunchDaemons`. mise manages user
  LaunchAgents only.
- Application Firewall rules (`socketfilterfw`). mise's firewall support is
  Linux-only.
- Lines in root-owned files such as `/etc/hosts`. mise's `[dotfiles] line`
  edits don't use sudo.
- System `defaults` domains, `nvram`, `pmset`, `systemsetup`, and `duti`.

User-domain `defaults write` calls fit `[bootstrap.macos.defaults]`, but they
stay in `defaults.sh`. Under mise they would be re-applied on every update and
undo changes made in System Settings.

## Guidelines

- Scripts must be safe to re-run. Guard one-time steps, such as restoring
  settings or opening apps for the first time, with a check for their result.
- Leave numbering gaps so later scripts can be inserted without renumbering

## 1Password Secrets

Use account and vault UUIDs for `op` calls in bootstrap scripts. Vault names such
as `Private` can exist in multiple 1Password accounts on the same machine.
Use the vault UUID in the secret reference and pin the account with `--account`.
Item titles remain readable unless their name is expected to change.

### Machines without 1Password

The NAS has no 1Password app or CLI session, so place its secrets by hand. A
bootstrap script that can't read a secret prints a warning naming the file and
the 1Password item, then skips that step.

| File                             | Source                                                                        |
| -------------------------------- | ----------------------------------------------------------------------------- |
| `~/.config/lazy-mcp/memos-token` | Password of `Memos OpenCode API token` in `Private`                           |
| atuin login                      | `atuin login -u <username>` with the key from `atuin key` on a synced machine |
