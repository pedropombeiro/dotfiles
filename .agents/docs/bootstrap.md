# Bootstrap

YADM bootstrap scripts for automated system setup.

## Structure

```
~/.config/yadm/
├── bootstrap              # Main entry point
└── bootstrap.d/           # Numbered scripts (run in order, 000-999)
    ├── 000-099            # Early setup (machine class, touchid, launch agents, software install, authentication, zinit, firewall, spotlight, mise, grc-rs rules)
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
on macOS, `update.zsh` runs `mise bootstrap` for packages, repositories, and user
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

- A script that fails a required step must exit non-zero; bootstrap stops at
  the first failing script. The entry point finds scripts with stock macOS
  tools, so don't depend on Homebrew or mise tools before `005` installs them.
- `007-check-authentication.sh` waits for the 1Password SSH agent and CLI, GitLab
  SSH access, and `gh`/`glab` logins before `010` clones private repositories.
- `100-wait-for-synced-data.sh` waits for `~/Sync/pedro` before `110`, `120`,
  and `938` restore from it. Syncthing isn't allowed on Work machines, so copy
  `~/Sync/pedro/.dotfiles/Home/MBP.Work`,
  `~/Sync/pedro/Briefcase/Backups/MBP.Work`, and
  `~/Sync/pedro/Briefcase/Backups/dash` from the previous Work machine.
  Don't add Syncthing to the Work Brewfile.
- Relinking preserves restored histories. Differing local histories are saved in
  `${XDG_STATE_HOME:-~/.local/state}/yadm/history-backups/restore.*` before linking.
  If a history has no restored copy, relinking copies the local file into the
  restored directory.
- Checkpoints that wait for a manual step use `wait_for` from
  `scripts/wait-for.sh`.
- Scripts must be safe to re-run. Guard one-time steps, such as restoring
  settings or opening apps for the first time, with a check for their result.
- Leave numbering gaps so later scripts can be inserted without renumbering

## Manual steps

Bootstrap leaves these to you on purpose. Don't automate or flag them as gaps.
`999-print-manual-steps.sh` lists them when bootstrap finishes.

- **App Store sign-in:** `005` tries to install App Store apps, which fails until
  you sign in. Rerun `mise bootstrap --only packages --yes` afterwards.
- **macOS permissions:** grant Accessibility, Bluetooth, and similar permissions
  when apps ask. Hammerspoon needs Accessibility and Bluetooth.
- **BusylightHTTP (Work):** install it from a local installer file. `940` only
  adds it as a login item.
- **GDK configuration (Work):** `950` installs GDK, and `update-work.zsh`
  configures it. A new machine doesn't need GDK right away, so run
  `mise run dotfiles:update` from a new terminal after bootstrap. Shell startup
  exports `GDK_ROOT` when `~/gitlab-development-kit` or `~/gdk` exists, preferring
  `~/gitlab-development-kit` when both exist. If you choose another installation
  directory, set `GDK_ROOT` to that directory before running the update.

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
