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
   `run-checks-common.zsh`.
1. **Conditions inside a single file.** When the file is code, branch at
   runtime. For example, `mason-tool-installer.lua` checks `vim.g.distro` and
   `vim.g.yadm_class`.
1. **Template.** Use `##template` to insert a value, such as
   `core/class.lua##template`, or to add conditional sections when the tool
   has no include feature, such as `lazy-mcp/servers.json##template`.
1. **Full-copy alternates.** Use separate alternates for small files, and for
   files that the owning tool writes to.
1. **Separate directories.** Use them only for content that a script syncs from
   elsewhere, such as `~/.agents/skills.work/`.

Don't template a file that its tool writes to. A full-copy alternate is a
symlink, so the tool's writes land in the tracked file and appear in
`yadm diff`. A template renders a plain file, so the tool's writes stay
untracked and yadm overwrites them on the next `yadm alt`.

## Duplication check

`~/.config/yadm/scripts/check-alt-duplication.zsh` fails when two non-template
alternates of the same file share more than 50 non-blank lines. It runs from
the hk `pre-commit` hook and from `run-checks-common.zsh`.

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

## Secrets

Never commit secrets, encrypted or not. Store them in 1Password and read them at
runtime or during bootstrap. gitleaks runs in the hk hooks and CI.
