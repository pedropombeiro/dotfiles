# Personal AI Agent Instructions

Read and follow all instructions in the `.ai/` directory.

## GDK Update Rule

**Never update from remote manually** — do not run `git pull`, `git fetch` + `git rebase`,
or `gdk update` directly. Always use `fgdku` instead; it handles fetching, rebasing all
branches, bundle install, migrations, GDK restart, and post-update cleanup in the correct
order. See the [GDK skill](.opencode/skills/gdk/SKILL.md) for how to run it.

## Learning Protocol

When the user corrects you or points out a mistake:

1. Acknowledge the correction.
2. Determine which category it falls into: code-style, testing, git, database, code-review, merge-requests, or general.
3. Append a concise, actionable lesson to the corresponding `.ai/<category>.local.md` file.
   - If the file does not exist yet, create it with a `# <Category> - Personal Lessons` heading.
   - For general lessons that do not fit a specific category, use `.ai/lessons-learned.local.md`.
4. Keep entries short (1-2 lines), framed as "Do X" or "Don't do Y" rules.
5. Do not duplicate existing entries.

## Context Loading (Personal)

When loading a module from `.ai/` (for example, `.ai/testing.md`), also check for and load its `.local.md` counterpart
if it exists (for example, `.ai/testing.local.md`). Always load `.ai/lessons-learned.local.md` if it exists.
