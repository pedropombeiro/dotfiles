# GDK Dotfiles Sync

Personal files that should appear inside `$GDK_ROOT/gitlab/` but not be committed to the
canonical repo live in the private `gitlab.com/pedropombeiro/gitlab-dotfiles` repository, cloned to:

```
~/.config/dotfiles/gitlab/
```

## How it works

`~/.config/yadm/scripts/update-work.zsh` defines `_sync_dotfiles_to_worktree()` and
`_sync_gitlab_dotfiles_specs()`, called from `sync_dotfiles_to_gitlab()`:

1. Walks **all** files (including hidden) under `~/.config/dotfiles/gitlab/` using
   `fd --hidden --type f`.
2. For each file, computes the relative path and maps it to `$GDK_ROOT/gitlab/<rel_path>`.
3. If the target exists as a regular file (not a symlink), copies it back to dotfiles first
   (preserves edits made directly in the GDK repo).
4. Ensures the target is a symlink pointing to the dotfiles source.
5. Appends `/<rel_path>` to `$GDK_ROOT/gitlab/.git/info/exclude` (deduped) so git ignores it.
6. Discovers additional git worktrees via `git worktree list --porcelain` and repeats
   steps 2–5 for each worktree under `$GDK_ROOT`. Worktree exclude entries go to
   `.git/worktrees/<name>/info/exclude`.

> **Gotcha:** the `fd` call must include `--hidden` and exclude `.git`, `.gitignore`, and
> `hk.pkl`. Without `--hidden`, `fd` silently skips `.opencode/`, `.ai/`, and `.gitlab/`.
> Without the exclusions, it syncs private repository metadata into the GitLab worktree.

## Bootstrap and updates

The checkout is declared in the work-only mise configuration under `[bootstrap.repos]`, so personal
machines do not clone it. On a fresh work machine:

1. Clone the public YADM repository over HTTPS.
2. Run `yadm bootstrap` to install 1Password and the remaining prerequisites.
3. Sign in to 1Password and enable its SSH agent when prompted.
4. Re-run `yadm bootstrap`. The existing repository bootstrap steps run `mise bootstrap repos apply` for every repository declared under `[bootstrap.repos]`.

Configured repositories can use different Git hosts and authentication methods. The private GitLab
checkout requires the 1Password SSH agent, while public HTTPS repositories do not.

`mise run dotfiles:update` refreshes configured repositories with `mise bootstrap repos update --skip-dirty` before syncing files into the GDK worktrees. Dirty repositories are left untouched.

## Adding new files

Place the file under `~/.config/dotfiles/gitlab/` at the same relative path you want it to
appear in the gitlab repo. No script changes are needed — `sync_dotfiles_to_gitlab()` picks
it up automatically on the next `mise run dotfiles:update`.

Commit and push it from the private repository:

```bash
git -C ~/.config/dotfiles/gitlab add <path>
git -C ~/.config/dotfiles/gitlab commit
git -C ~/.config/dotfiles/gitlab push
```

## Current contents

Do not hand-maintain an inventory here — it drifts. List ground truth with:

```bash
fd --hidden --type f . ~/.config/dotfiles/gitlab/
```

Broadly: `CLAUDE.local.md`, `lefthook-local.yml`, the `.ai/*.local.md` lesson files,
`.gitlab/duo/chat-rules.md`, `.opencode/commands/`, and the `.opencode/skills/` tree.

> The `glab` skill used to live here too. It was a stale fork of the git-tracked
> `.claude/skills/glab/` (which is the SSOT, synced to `gitlab-org/ai/skills`) and was
> shadowed by it at load time, so it was removed.

## Why not `##class.Work` alternates?

Previously, Work-class skills and commands used YADM alternate files (e.g.,
`SKILL.md##class.Work`) in their global locations (`~/.agents/skills/`, `~/.config/opencode/commands/`).
This made them active globally rather than only inside the gitlab repo. Moving them to
`~/.config/dotfiles/gitlab/` and symlinking via `update-work.zsh` scopes them to the
GDK gitlab project only, with no alternates needed.

## Troubleshooting

**Symlinks missing after a sync?** Run `mise run dotfiles:update` (the task that invokes
`update-work.zsh`). Check `$GDK_ROOT/gitlab/.git/info/exclude` for entries matching the
expected paths. If entries exist but symlinks are absent, the target directory may have been
deleted; re-running the sync recreates them.

**Stale exclude entries** (orphaned paths whose dotfile source was removed or renamed) are
cleaned up by `cleanup_gitlab_excludes()` in `update-work.zsh`. Add a `sed -i ''` line there
for any path you rename or remove.
