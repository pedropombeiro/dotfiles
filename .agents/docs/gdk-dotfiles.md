# GDK Dotfiles Sync

Personal files that should appear inside `$GDK_ROOT/gitlab/` but not be committed to the
canonical repo live under a single well-known location in the dotfiles repo:

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

> **Gotcha:** the `fd` call must include `--hidden`; without it `fd` silently skips all
> hidden directories (`.opencode/`, `.ai/`, `.gitlab/`, etc.) and none of those files get
> synced.

## Adding new files

Place the file under `~/.config/dotfiles/gitlab/` at the same relative path you want it to
appear in the gitlab repo. No script changes are needed — `sync_dotfiles_to_gitlab()` picks
it up automatically on the next `mise run dotfiles:update`.

Track it with YADM: `yadm add ~/.config/dotfiles/gitlab/<path>`.

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
