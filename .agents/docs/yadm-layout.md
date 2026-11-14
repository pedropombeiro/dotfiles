# YADM Repository Layout

Rules for where files go in the dotfiles repository and how they vary between
machines. For yadm commands and commit conventions, see [SCM](scm.md).

## Scope

The repository holds configuration for tools used on more than one machine, and
the scripts that install and maintain it. Keep projects in their own
repositories and link their entry points from
`~/.config/yadm/scripts/relink-dotfiles.zsh`. For example, that script links the
`pedropombeiro/gopro-graphics` scripts into `~/.local/bin` when the repository
exists under `~/Developer`.

Every file at the repository root lands in `$HOME`. Keep only files that tools
require at the root, such as `LICENSE`, `hk.pkl`, and linter configs. Put
repository documentation in `.github/`.

## Machine identity

Every machine sets exactly one class with `yadm config local.class CLASS`.
`000-ensure-machine-class.sh` aborts bootstrap unless the class is `Personal`,
`Work`, or `NAS`.

| Condition      | Use for                                                       |
| -------------- | ------------------------------------------------------------- |
| `class.<NAME>` | What the machine is for: services, hosts, identities, aliases |
| `os.<NAME>`    | Differences between macOS and Linux                           |
| `distro.qts`   | QTS platform limits: old glibc, Entware paths, QNAP tools     |

Don't use `distro.qts` as a stand-in for the NAS role. If a file would still apply after the
NAS role moved to another operating system, match it on `class.NAS`.

Don't give a machine more than one class. When several alternates match, yadm
prefers the one with more conditions, then the higher-weighted condition, and
`class` outweighs `distro` and `os`. An extra class makes that choice hard to
predict. For example, `class.Personal` would beat `distro.qts` on the NAS.

## Varying a file between machines

Choose the first approach that fits:

1. **Base file with an include.** Keep shared content in one tracked file and
   include a small per-machine alternate. Use this approach when the tool
   supports includes, for example `~/.config/git/config` including
   `config-specific##class.NAS`, or a script that sources
   `scripts/lib/check-helpers.zsh`.
1. **Conditions inside a single file.** When the file is code, branch at
   runtime. For example, `mason-tool-installer.lua` checks `vim.g.distro` and
   `vim.g.yadm_class`.
1. **Template.** Use `##template` to insert a value, such as
   `core/class.lua##template`, or to add conditional sections when the tool
   has no include feature, such as `lazy-mcp/servers.json##template`.
1. **Full-copy alternates.** Use separate alternates for small files, and for
   files that the owning tool writes to.
1. **Separate directories per machine.** Use them only for content that a script
   syncs from elsewhere, such as `~/.agents/skills.work/`.

Don't template a file that its tool writes to. A full-copy alternate is a
symlink, so writes through the link land in the tracked file and appear in
`yadm diff`. A template renders a plain file, so the tool's writes stay
untracked and yadm overwrites them on the next `yadm alt`.

Some tools save by writing a temporary file and renaming it over the original,
which replaces the symlink instead of writing through it. Neither approach
works for those files. Keep the tool's file untracked and put the tracked
settings in a file that the tool reads in addition, as
[OpenCode's terminal config](opencode.md#terminal-config) does with
`cli.base.json`.

## Script libraries

Put reusable sourced helpers in `~/.config/yadm/scripts/lib/`, including output
helpers, update UI functions, approval functions, and shared data lists. Keep
workflow entry points and standalone maintenance commands at the top level.
Libraries must preserve the caller's `YADM_SCRIPTS` as the scripts root, not the
`lib/` directory. Resolve sibling helpers relative to the library file when
possible, and preserve each library's shell compatibility.

The top-level `colors.sh` and `iterm2.sh` files forward to their implementations
in `lib/` for existing NAS callers. Use the `lib/` paths for new callers. Remove
these compatibility files only after the NAS repository's callers migrate.

## Update workflows

`mise run dotfiles:update` calls the ordinary executable `scripts/update.zsh`.
The entry point loads direct `updates.d/*.zsh` entries in filename order and
ignores `##` source files. YADM selects platform and role alternates. Work
modules require both `os.Darwin` and `class.Work`, preserving the previous
macOS-only workflow. QTS package updates use `os.Linux,distro.qts` because they
depend on Entware and QNAP paths.

Modules define functions and register steps with
`_update_register [--interactive] "label" function_name`. They must not run
updates at source time. Functions must exist before registration, and each
registered function must have a unique name across the selected modules.
Use `_update_use_sudo` to request credentials before execution and
`_update_watch manager...` to declare package snapshots. Manager declarations
are deduplicated in registration order. The `skills` manager compares
`skillFolderHash` values in `~/.agents/.skill-lock.json`, so the summary lists
skills that `npx skills update` changed.

The runner validates every selected module before loading it, then calculates
the progress total from registered steps. Empty discovery, invalid entries,
syntax errors, and registration failures abort before live steps start. An
individually missing module or alternate link is not detected while others
remain. Registration-only fixture tests cover the expected machine selections.

Step functions run in the main shell with `ERR_RETURN`. Use `return`, not
`exit`, and keep shell-option changes local. Shared state persists between
steps, including Homebrew's running-app snapshot for download approval.
Failures stop the affected step, not the workflow. `_update_warn` and
`_update_note` preserve warnings and notes for the summary, and
`UPDATE_FAILURE_FILE` carries explicit diagnostics from child scripts.
The final status is nonzero if any step fails.

Preserve ordering when adding modules. Package updates precede dependent
maintenance, Zinit precedes bytecode compilation, Work repositories precede
GDK configuration, and Brew dump runs last. Keep related private helpers with
their owning module. Shared helpers belong in `lib/`: `update-runner.zsh`
handles registration and orchestration, `update-ui.zsh` handles step output
and lifecycle, `update-packages.zsh` handles version comparisons, and
`startup-benchmark.zsh` handles benchmark history and reporting.

Make new modules executable, stage alternate sources with `yadm add`, and run
`yadm alt` to activate selected links. Never stage generated links. Run
`zsh -df ~/.config/yadm/scripts/tests/test-update-runner.zsh`.
The fixture tests cover order, shared state, interactive
steps, failures, cleanup, and NAS `PROGRESS_OFFSET` and `PROGRESS_RANGE` support.
CI runs all `scripts/tests/test-*.zsh` suites without executing live updates.

## Health checks

`mise run dotfiles:checkhealth` calls `~/.config/yadm/scripts/run-checks.zsh`.
The runner executes direct `*.zsh` children of `scripts/checks.d/` in filename
order, each in its own process. It continues after failures and exits nonzero
if any check fails. An empty discovery result, broken links, and non-executable
entries are errors. An individually absent module or selected alternate link
isn't detected when other checks exist.

Add shared checks as ordinary executable files. For platform or role checks,
use YADM alternates such as `010-tmux-local-network.zsh##os.Darwin` or
`100-desktop.zsh##os.Darwin,class.Work`. The runner discovers the selected
symlinks and ignores `##` source files. Give independent checks distinct
basenames because YADM selects only one alternate per basename. Stage new
alternates and run `yadm alt` to activate them.

Checks can source `scripts/lib/check-helpers.zsh` for output helpers and the
`any_failed` accumulator. Exit with that status after running all checks in
the module. Warnings alone don't set it. `print_failure` preserves
`UPDATE_FAILURE_FILE` reporting without marking repaired issues as failures.
Runtime guards still handle optional tools, running services, and repository
availability. Keep related checks together when they share state or ordering.

Run `zsh ~/.config/yadm/scripts/tests/test-run-checks.zsh` to test discovery and
failure handling with isolated fixtures, without running live health checks.

`scripts/tests/` holds regression tests with fixtures and mocks. They don't run
as part of health checks. `scripts/validators/` holds CI and hook validators.
Health checks can call a validator when the same validation is useful at runtime,
as `checks.d/060-alt-duplication.zsh` does. Update workflows can call individual
health checks directly, including the telemetry check's `--fix` mode.

### Add a health check

1. Choose the owner and directory. Put shared machine and tool checks in the
   dotfiles repository's `scripts/checks.d/`. Put NAS infrastructure and service
   checks in the [NAS repository](https://github.com/pedropombeiro/nas), following
   its local agent instructions. Put fixture and mock tests in `scripts/tests/`
   and CI or hook validators in `scripts/validators/`.
1. Choose a numbered, descriptive basename in the existing filename order.
   Use an ordinary `.zsh` file for shared checks or a YADM alternate for machine
   restrictions. Follow the [machine identity rules](#machine-identity): use
   `os` for platform differences, `class` for roles, and `distro.qts` for QTS
   limitations. Checks that must both run need distinct basenames.
1. Follow the module contract. A typical Zsh module starts with:

   ```zsh
   #!/usr/bin/env zsh

   set -o pipefail
   source "${${(%):-%x}:A:h:h}/lib/check-helpers.zsh"
   ```

   Keep related checks and required state in the same module. Shell variables,
   functions, options, and directory changes don't carry over between modules.
   Guard optional dependencies and make any repair actions explicit. Use
   `print_warn` for nonfatal warnings. For a failure, call `print_failure` and
   set `any_failed=1`. The helper records diagnostics in `UPDATE_FAILURE_FILE`
   when supplied, but doesn't set the failure status. Finish the module with
   `exit "$any_failed"` so later successes don't hide earlier failures.
1. Make the source file executable with `chmod +x`. Stage new alternate sources
   with `yadm add`, then run `yadm alt` to activate the applicable links and
   regenerate their ignore entries. Never stage generated alternate links.
1. Update the expected machine-selection lists in
   `scripts/tests/test-run-checks.zsh` when adding or renaming a module. Add
   focused fixtures for the module's behavior, including failures, optional
   dependencies, and repairs where applicable. Keep tests isolated from live
   services and hardware.
1. Run `zsh -n` on the source file. Execute
   `zsh ~/.config/yadm/scripts/tests/test-run-checks.zsh` and the affected
   regression tests. Run `yadm enter hk check --all` before committing, but don't
   rely on it alone: hk's global `.config` exclusion omits these
   scripts. Don't run live checks that launch applications, restart services,
   or change hardware state without explicit approval.

### NAS integration

The NAS health-check runner calls
`~/.config/yadm/scripts/run-checks.zsh` once and includes its exit status in the
overall result. Keep this public entry point stable. NAS callers shouldn't
depend on individual dotfiles module filenames, and the dotfiles runner
mustn't invoke the NAS runner. This one-way dependency prevents duplicate
checks and recursive execution. Follow the NAS repository's own guide for its
Bash module contract.

## Duplication check

`~/.config/yadm/scripts/validators/check-alt-duplication.zsh` fails when two non-template
alternates of the same file share more than 50 non-blank lines. It runs from
the hk `pre-commit` hook and from `checks.d/060-alt-duplication.zsh`.

The script lists files that keep full copies because their tools write to
them:

- `.Brewfile`, written by `mise run brew:dump`
- The iTerm2 preferences `.plist`
- `.config/opencode/opencode.json`, updated by OpenCode
- `.config/pgcli/config`, where pgcli saves `\ns` named queries

Add a file to that list only for the same reason. OpenCode's
`OPENCODE_CONFIG*` variables reach only `--standalone` sessions, so they can't
layer the global config.

## Third-party content

Fetch upstream files instead of tracking copies, and pin the version so
Renovate proposes updates. For example, the QTS `grc-rs:sync` mise task
downloads a pinned grc release, and Renovate reads the pin from its
`# renovate: datasource=... depName=...` comment.

Skills installed by `npx skills` are the exception. They stay tracked so
upstream changes show up in `yadm diff`.

## Public repository

The repository is public on GitHub. Track a Work file only if its content would
be acceptable in GitLab's public handbook. gitleaks catches credentials, but it
doesn't catch internal host names, Teleport or bastion hosts, staging and
production database names, internal-only projects, or private document links.
Review Work-class changes for these by hand before committing.

Put internal Work files under `home/` in the private `gitlab-dotfiles`
checkout. See [GDK dotfiles sync](gdk-dotfiles.md#private-files-for-home).

## Secrets

Never commit secrets, encrypted or not. Store them in 1Password and read them at
runtime or during bootstrap. gitleaks runs in the hk hooks and CI.
