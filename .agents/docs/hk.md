# hk

Git hooks and code quality checks for the yadm dotfiles repo.

## Agent skills

Use the hk release's `hk-configure` and `hk-debug` skills for general setup and
diagnosis. Use the local `hk-yadm` skill alongside them for dotfiles work.
The bundled skills were reviewed at hk v2.1.0 and linked manually through mise.
See [Packslip skills policy](mise.md#completions-and-skills-policy) for updates.

## Configuration

**Main config**: `~/hk.pkl` (requires hk v2.1.0+)

hk is installed globally via `hk install --global`, using Git 2.54+ config-based hooks. It runs as a
silent no-op in repos without an `hk.pkl`.

### yadm-specific settings

Two settings in `hk.pkl` are needed to make hk work cleanly in the yadm context
(`GIT_WORK_TREE=$HOME`):

- **`env { ["HK_STASH_UNTRACKED"] = "false" }`** — prevents hk from running
  `git status --untracked-files=all` which would scan the entire home directory (~45s).
  See [jdx/hk#860](https://github.com/jdx/hk/discussions/860).
- **`stash = "none"`** on the pre-commit hook avoids a recursive hook invocation.
  `hk install --global` registers a hook on every git operation, so the internal `git stash push`
  hk runs during pre-commit would re-trigger hk and cause an infinite loop. Downside: if you have
  unstaged changes, auto-fixers may modify them alongside staged content.
  Other hooks, including `fix`, default to no stashing in hk v2.

## Running Hooks Manually

In hk v2, `hk fix` and `mise run dotfiles:fix` leave fixes unstaged for review.
Use `yadm enter hk fix --stage` to stage fixes. Only `pre-commit` auto-stages by default.

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

Do not mirror the step list here — it drifts from `hk.pkl`. List the live plan with
`yadm enter hk check --plan`, which also shows which steps matched files.

`commitlint` is the one step not in that plan: it lives under the `commit-msg` hook, not
`fast_steps`.

## CI Integration

The `hk-check` job in `.github/workflows/ci.yml` runs `hk check --all` via `jdx/mise-action`,
which installs all tools from the Linux mise config. Steps skipped in CI:

- `standardrb` — requires Ruby gems not in CI
- `renovate-config-validator` — requires npm:renovate
- `no-yadm-alt-symlinks` — requires yadm

The separate `luacheck` job lints `.config/nvim/**/*.lua` since hk's global exclude
hides `.config/` from scanning.

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

hk version is pinned in `~/.config/mise/conf.d/global.toml`.
When upgrading, bump the `amends` and `import` URLs and `min_hk_version` in `~/hk.pkl`
to match the new version.

Keep the mise pin aligned with these values. `mise install` can reuse an older
cached installation for `latest`, including in CI.

Check current version: `hk --version`

After upgrading, run `yadm enter hk validate`. hk v2 uses its built-in Pkl
evaluator and does not require the standalone `pkl` CLI.

## Caveats

### Steps follow symlinks out of the repo and can write to the target

Several steps walk the **filesystem**, not the git index, so a symlink pointing outside
`$HOME` pulls the target's files into scope. Being untracked is not protection.

For fixer steps this is destructive: they write to a repo you did not intend to touch, and
the edit lands silently because the file is untracked (`yadm status` stays clean).

Mitigation: exclude the symlinked path per step, scoped as narrowly as possible so sibling
files keep coverage.

```pkl
["typos"] = (Builtins.typos) {
    exclude = binary_excludes + List(".agents/skills.work/orbit/*")
}
```

Prefer a path scoped to the symlink itself over a broad glob like
`.agents/skills/*/scripts/*`, which would also silence genuinely local files.

Do not broadly exclude `.agents/skills/*` from steps that operate on files supplied by
hk. Locally maintained skills should receive normal formatting and validation. Most
externally maintained skills are untracked symlinks and are absent from the staged/index
file list, but some imported skills are tracked copies, such as `opencode-refine`; add
narrow path exclusions for those. Tools that independently walk the filesystem still need
narrow exclusions for imported symlinks.

**When adding a symlink to a repo outside `$HOME`**, run `hk check --all`, then check
`git status` _in the target repo_ — not just `yadm status` — to confirm no fixer wrote to it.

### Global hook PATH issue

`hk install --global` writes hook commands to `~/.gitconfig` that call `hk` by name. Since hk
is managed by mise (not in a system PATH like `/opt/homebrew/bin`), any git invocation from a
subshell that doesn't load mise shims (e.g. Homebrew tap updates, IDE git operations) will fail
with `hk: command not found` and abort the git operation.

To fix this, the hook commands are patched to silently no-op when `hk` is not found:

```bash
# Instead of the default:
test "${HK:-1}" = "0" || hk run <event> --from-hook "$@"

# We use:
{ [ "${HK:-1}" = "0" ] || ! command -v hk >/dev/null 2>&1 ; } || hk run <event> --from-hook "$@"
```

**If you ever re-run `hk install --global`**, the default (broken) commands will be reinstalled.
Re-apply the patch with:

```bash
for event in commit-msg post-checkout post-commit post-merge post-rewrite pre-commit pre-push pre-rebase prepare-commit-msg; do
  git config --global "hook.hk-${event}.command" \
    "{ [ \"\${HK:-1}\" = \"0\" ] || ! command -v hk >/dev/null 2>&1 ; } || hk run ${event} --from-hook \"\$@\""
done
```
