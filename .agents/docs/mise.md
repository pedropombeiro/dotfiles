# Mise

Runtime versions and CLI tool management.

## Configuration

`~/.config/mise/config.toml` is a YADM alternate: `##default` on macOS and
`##distro.qts` on QTS. Layered configs live in `~/.config/mise/conf.d/`.
Use `mise config ls` to see active files and `mise ls <tool>` to find the source
of a version selection. Read the configuration for current tool versions.

`conf.d/bootstrap.toml` declares repositories and user LaunchAgents. YADM
bootstrap invokes explicit `--only` scopes; do not run bare `mise bootstrap`,
because its dotfile, macOS default, and user configuration overlap YADM workflows.

See [Mise tasks](mise-tasks.md) for task locations and authoring rules, and
[backend troubleshooting](mise-backends.md) for install failures and backend policy.

### Config precedence

`~/.config/mise/config.toml` outranks `conf.d/*`. To vary a tool per machine class,
declare it only in the matching environment fragment. A duplicate declaration in
`config.toml` overrides the fragment.

### Config environments

The YADM-selected `~/.config/mise/miserc.toml` enables `env_conf_d`, `auto_env`,
and the explicit `personal`, `work`, `linux-standard`, or `qts` environment.
Platform fragments such as `tools.linux.toml` load through `auto_env`.

Explicit environments outrank automatic platform environments. On QTS,
`tools.qts.toml` overrides `tools.linux.toml` for incompatible runtimes and libc
settings. Put tools that work on every Linux host in `tools.linux.toml`, and
tools requiring a current distribution in `tools.linux-standard.toml`.

These early settings do not appear in `mise settings`; verify them through
`mise config ls` and the resulting toolset.

### Inactive platform installs

`mise prune` treats tracked configs as authoritative even when their platform is
inactive. An inactive tool's shim can shadow another installation or fail with
`No version is set for shim`.

Remove inactive installs with `mise uninstall --all <tool>`, then run
`mise reshim --force`. If no other package manager provides the tool on the current
platform, move its declaration to `conf.d/global.toml`. Confirm that its backend
works on every target platform without a platform-specific compiler toolchain.

### GitHub credentials

Use global `settings.github.credential_command = "gh auth token"` for lazy
authentication. `env._.source` runs on every environment refresh, and the default
`github.gh_cli_tokens = true` cannot retrieve a token stored only in the macOS
keychain. mise ignores `github.credential_command` in project config.

## Packslip backend

[Packslip](https://packslip.dev) supplies vendor-signed release manifests with
binaries and version-matched resources. Prefer it when the vendor publishes a
signed manifest. mise verifies the Sigstore signature and artifact checksums.

Check availability with `mise backends ls` and `mise registry`. Registry entries
can select Packslip without an explicit prefix; use `mise tool <name>` to inspect
the resolved backend and security metadata.

To check a vendor release for a manifest:

```bash
curl -fsSL https://api.github.com/repos/OWNER/REPO/releases/latest \
  | jq '[.assets[].name] | map(select(test("packslip")))'
```

Before pinning a Packslip version, check Renovate's support for the backend.
`latest` entries do not need version updates; the existing backend grouping rule
matches mise config by path.

### Completions and skills policy

Keep static completions in
`~/.shellrc/zshrc.d/configs/pre/060-generate-completions.zsh` until a tool needs
version-specific completions. Packslip completions follow the active version
through shell activation.

Keep `skills.auto_sync` disabled so tool upgrades cannot change agent instructions
without review. `~/.agents/skills` contains both YADM-tracked directories and
manually managed links.

| Setting            | Default          | Local policy                                      |
| ------------------ | ---------------- | ------------------------------------------------- |
| `skills.fetch`     | `true`           | Keep enabled; fetching does not activate a skill. |
| `skills.dir`       | `.claude/skills` | Set explicitly for a manual sync.                 |
| `skills.auto_sync` | `false`          | Keep disabled.                                    |
| `skills.prune`     | `false`          | Use only with a reviewed manual sync.             |
| `packslip.exec`    | `false`          | Keep disabled unless a resource requires it.      |

To activate reviewed skills on another machine or after an upgrade:

1. Run `mise skills ls` and review every listed skill at its installed path.
2. Run `mise skills sync --dir "$HOME/.agents/skills"`. This syncs all listed
   skills, including those bundled with hk.
3. Restart the agent so it discovers the new skills.

Generated symlinks and `.mise-skills.json` are untracked local installation state.
Repeat review and manual sync after upgrades. Retain the old installed version
until its skill links are updated. Keep narrow hk exclusions for linked upstream
skills; locally maintained skills receive normal checks. See [hk guidance](hk.md)
for skill selection.

## QNAP/QTS compatibility

QTS has glibc 2.21 limitations. Pins live in
`~/.config/mise/conf.d/tools.qts.toml`.

- Python requires GNU precompiled binaries because QTS has no musl loader.
  Set `precompiled_arch = "x86_64"` and `precompiled_os = "unknown-linux-gnu"`.
  The `x86_64_v2` build embeds compiler flags unsupported by GCC 8.4, breaking
  C extensions. Python and its CLI tools are mise-managed; do not install opkg
  `python3` or `python3-pip`.
- Node uses `mirror_url = "https://unofficial-builds.nodejs.org/download/release/"`
  and `flavor = "glibc-217"` under `[settings.node]`.

## Common operations

```bash
mise install          # Install tools from config
mise use <tool>       # Add a tool
mise upgrade          # Update tools
mise list             # List installed tools
mise outdated         # Check for outdated tools
```

Prefer mise-managed tools over system packages. Use `latest` where appropriate
and document QTS compatibility constraints. Prefer `github:` or `aqua:` over
compiler-backed backends when suitable cross-platform release artifacts exist.

## Tool postinstall hooks

Attach tool-specific setup to that tool's `postinstall` option. It runs after
installation or reinstallation and receives `MISE_TOOL_NAME`, `MISE_TOOL_VERSION`,
and `MISE_TOOL_INSTALL_PATH`. Avoid a global `[hooks].postinstall` script that
inspects `MISE_INSTALLED_TOOLS` for setup belonging to one tool.

Safe mode (`MISE_SAFE=1`) blocks tool-level postinstall hooks.

## Renovate integration

Renovate updates tool pins through `~/.renovaterc.json`. Check pending PRs before
manual upgrades. See [Renovate guidance](renovate.md) for rules and troubleshooting.
