# GDK Dotfiles Sync

Personal files that should appear inside `$GDK_ROOT/gitlab/` but not be committed to the
canonical repo live under a single well-known location in the dotfiles repo:

```
~/.config/dotfiles/gitlab/
```

## How it works

`~/.config/yadm/scripts/update-work.zsh` defines `sync_dotfiles_to_gitlab()`, which:

1. Walks every file under `~/.config/dotfiles/gitlab/`.
2. For each file, computes the relative path and maps it to `$GDK_ROOT/gitlab/<rel_path>`.
3. If the target exists as a regular file (not a symlink), copies it back to dotfiles first
   (preserves edits made directly in the GDK repo).
4. Ensures the target is a symlink pointing to the dotfiles source.
5. Adds the relative path to `$GDK_ROOT/gitlab/.git/info/exclude` so git ignores it.

## Adding new files

Place the file under `~/.config/dotfiles/gitlab/` at the same relative path you want it to
appear in the gitlab repo. No script changes are needed — `sync_dotfiles_to_gitlab()` picks
it up automatically on the next `mise run dotfiles:update`.

Track it with YADM: `yadm add ~/.config/dotfiles/gitlab/<path>`.

## Current contents

| Dotfiles path                             | Purpose                                |
| ----------------------------------------- | -------------------------------------- |
| `AGENTS.local.md`                         | Personal AI agent instructions         |
| `.ai/code-style.local.md`                 | Ruby code style lessons                |
| `.ai/lessons-learned.local.md`            | General AI corrections                 |
| `.ai/testing.local.md`                    | RSpec testing conventions              |
| `.opencode/commands/review-mr.md`         | Multi-agent MR review command          |
| `.opencode/commands/weekly-update.md`     | Weekly milestone status update command |
| `.opencode/skills/clickhouse/SKILL.md`    | ClickHouse dev database skill          |
| `.opencode/skills/db-migrations/SKILL.md` | Branch migration list/undo skill       |
| `.opencode/skills/gdk/SKILL.md`           | GDK update & secrets skill             |
| `.opencode/skills/git-helpers/SKILL.md`   | Git branch management helpers skill    |
| `.opencode/skills/glab/SKILL.md`          | GitLab CLI workflow skill              |
| `.opencode/skills/mr-pipeline/SKILL.md`   | MR pipeline coordination tools skill   |
| `.opencode/skills/mr-workflow/SKILL.md`   | MR lifecycle helpers skill             |
| `.opencode/skills/psql/SKILL.md`          | PostgreSQL dev database skill          |

## Why not `##class.Work` alternates?

Previously, Work-class skills and commands used YADM alternate files (e.g.,
`SKILL.md##class.Work`) in their global locations (`~/.agents/skills/`, `~/.config/opencode/commands/`).
This made them active globally rather than only inside the gitlab repo. Moving them to
`~/.config/dotfiles/gitlab/` and symlinking via `update-work.zsh` scopes them to the
GDK gitlab project only, with no alternates needed.
