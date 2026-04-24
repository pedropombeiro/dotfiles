# hk

Git hooks and code quality checks for the yadm dotfiles repo.

## Configuration

**Main config**: `~/hk.pkl` (requires hk v1.44.1+ for yadm bare-repo support)

hk is installed globally via `hk install --global`, using Git 2.54+ config-based hooks. It runs as a
silent no-op in repos without an `hk.pkl`.

### yadm-specific settings

Two settings in `hk.pkl` are needed to make hk work cleanly in the yadm context
(`GIT_WORK_TREE=$HOME`):

- **`env { ["HK_STASH_UNTRACKED"] = "false" }`** — prevents hk from running
  `git status --untracked-files=all` which would scan the entire home directory (~45s).
  See [jdx/hk#860](https://github.com/jdx/hk/discussions/860).
- **`stash = "none"`** on pre-commit and fix hooks — avoids a recursive hook invocation.
  `hk install --global` registers a hook on every git operation, so the internal `git stash push`
  hk runs during pre-commit would re-trigger hk and cause an infinite loop. Downside: if you have
  unstaged changes, auto-fixers may modify them alongside staged content.

## Running Hooks Manually

```bash
# Run all checks (all files)
yadm enter hk check --all

# Run all fixers (all files)
yadm enter hk fix --all

# Via mise tasks
mise run dotfiles:lint
mise run dotfiles:fix

# Dry-run: see what would run and why
yadm enter hk check --plan
```

## Configured Steps

| Step                            | Purpose                                        |
| ------------------------------- | ---------------------------------------------- |
| trailing-whitespace             | Remove trailing whitespace                     |
| newlines                        | Ensure files end with a newline                |
| check-merge-conflict            | Detect leftover conflict markers               |
| typos                           | Spell checking for source code                 |
| gitleaks                        | Secret detection                               |
| yamllint                        | YAML linting                                   |
| editorconfig-checker            | EditorConfig conformance                       |
| shellcheck                      | Shell script linting (bash/sh only)            |
| shfmt                           | Shell script formatting                        |
| zsh-syntax-check                | Zsh syntax validation (`zsh -n`)               |
| stylua                          | Lua formatting                                 |
| luacheck                        | Lua linting                                    |
| prettier                        | JSON/Markdown/YAML formatting                  |
| standardrb                      | Ruby linting/formatting                        |
| check-json                      | JSON parse validation                          |
| check-executables-have-shebangs | Executables must have shebangs                 |
| check-added-large-files         | Block files over 500KB                         |
| no-yadm-alt-symlinks            | Reject staged yadm alt symlinks                |
| mise-fmt                        | Mise config formatting                         |
| renovate-config-validator       | Renovate config validation                     |
| commitlint                      | Conventional commit messages (commit-msg hook) |

## CI Integration

The `hk-check` job in `.github/workflows/ci.yml` runs `hk check --all` via `jdx/mise-action`,
which installs all tools from the Linux mise config. Steps skipped in CI:

- `standardrb` — requires Ruby gems not in CI
- `renovate-config-validator` — requires npm:renovate
- `no-yadm-alt-symlinks` — requires yadm

## Bypassing Hooks

```bash
HK=0 yadm commit -m "wip"              # skip all hk hooks
HK_SKIP_STEPS=typos yadm commit -m ""  # skip a specific step
```

## Debugging

```bash
yadm enter hk check -v              # verbose output
yadm enter hk check --plan         # show what would run
yadm enter hk check --step stylua  # single step
```

## Adding New Steps

Edit `~/hk.pkl`. Add to the `fast_steps` mapping — it is shared across `pre-commit`, `fix`, and
`check` hooks. Run `yadm enter hk validate` to verify syntax.

## Version Management

hk version is managed by mise (`hk = "latest"` in `~/.config/mise/conf.d/global.toml`).
When upgrading, bump the `amends` and `import` URLs in `~/hk.pkl` to match the new version.

Check current version: `hk --version`
