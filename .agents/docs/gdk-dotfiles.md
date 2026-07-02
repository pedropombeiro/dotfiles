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

| Dotfiles path                                        | Purpose                                    |
| ---------------------------------------------------- | ------------------------------------------ |
| `CLAUDE.local.md`                                    | Personal AI agent instructions             |
| `lefthook-local.yml`                                 | Force UTF-8 for Ruby hooks (lazygit)       |
| `.ai/code-style.local.md`                            | Ruby code style lessons                    |
| `.ai/git.local.md`                                   | Git and branch workflow lessons            |
| `.ai/lessons-learned.local.md`                       | General AI corrections                     |
| `.ai/merge-requests.local.md`                        | MR lifecycle and issue-state lessons       |
| `.ai/testing.local.md`                               | RSpec testing conventions                  |
| `.gitlab/duo/chat-rules.md`                          | Duo chat persona rules                     |
| `.opencode/commands/review-mr.md`                    | Multi-agent MR review command              |
| `.opencode/commands/weekly-update.md`                | Weekly milestone status update command     |
| `.opencode/skills/clickhouse/SKILL.md`               | ClickHouse dev database skill              |
| `.opencode/skills/clickhouse/scripts/gdk-clickhouse` | ClickHouse helper script                   |
| `.opencode/skills/db-migrations/SKILL.md`            | Branch migration list/undo skill           |
| `.opencode/skills/gdk/SKILL.md`                      | GDK update & secrets skill                 |
| `.opencode/skills/git-helpers/SKILL.md`              | Git branch management helpers skill        |
| `.opencode/skills/glab/SKILL.md`                     | GitLab CLI workflow skill                  |
| `.opencode/skills/glab/assets/graphql/*.graphql` (3) | GraphQL query files for glab skill         |
| `.opencode/skills/glab/references/*.md` (5)          | Reference docs for glab skill              |
| `.opencode/skills/glab/scripts/*.sh` (2)             | Helper scripts for glab skill              |
| `.opencode/skills/issue-state/SKILL.md`              | Issue status/MR-sync + start-issue skill   |
| `.opencode/skills/issue-state/scripts/*.sh` (5)      | Helper scripts for issue-state skill       |
| `.opencode/skills/mr-pipeline/SKILL.md`              | MR pipeline coordination tools skill       |
| `.opencode/skills/mr-workflow/SKILL.md`              | MR lifecycle helpers skill                 |
| `.opencode/skills/orbit/SKILL.md`                    | Orbit analytics skill                      |
| `.opencode/skills/orbit/references/*.md` (3)         | Reference docs for orbit skill             |
| `.opencode/skills/psql/SKILL.md`                     | PostgreSQL dev database skill              |
| `.opencode/skills/repo-bootstrap/SKILL.md`           | Repo bootstrap / first-session setup skill |
| `.opencode/skills/tool-routing/SKILL.md`             | Tool routing / MCP dispatch skill          |

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
