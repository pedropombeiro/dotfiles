# Agent Instructions

This file contains core instructions applicable to most tasks. For specialized topics, see the linked documents below.

## Specialized Topics

- [Shell](~/.agents/docs/shell.md) - Zsh configuration, zinit plugins, functions
- [Bootstrap](~/.agents/docs/bootstrap.md) - YADM bootstrap scripts for system setup
- [Tmux](~/.agents/docs/tmux.md) - Configuration structure, plugins, and shell integration
- [OpenCode](~/.agents/docs/opencode.md) - Policy overrides and runtime behaviors
- [Beads](~/.agents/docs/beads.md) - Issue tracking with bd, Dolt database, cross-machine sync
- [GDK Dotfiles](~/.agents/docs/gdk-dotfiles.md) - Personal files synced into `$GDK_ROOT/gitlab`
- [Developer Directory](~/.agents/docs/developer-directory.md) - Repo clone path convention (`~/Developer/<forge>/<owner>/<repo>`)
- [Architecture Decisions](~/.agents/docs/adr/) - ADRs for key tool choices

## Dotfiles (YADM)

**Always use `yadm` instead of `git`** when working with files in:

- `~/.config/`
- `~/.shellrc/`
- `~/.agents/docs/`
- `~/.claude/`
- Any dotfiles in `~` (the home directory is not a git repo)

NOTE: By `~/` we take it to mean the home directory (`$HOME`).

When searching for configuration files or code in the home directory, use YADM commands for much faster results:

- `yadm ls-files` - List all tracked dotfiles
- `yadm grep <pattern>` - Search content within tracked dotfiles

These commands only search files tracked by YADM, avoiding the slow traversal of the entire home directory.

## Searching files or file content in a home directory

Always favor searching using `yadm ls-files` and `yadm grep` over `glob`/`find` and `grep` tools, given the large
amount of unrelated files present under a home directory.

## Continuous Learning

When the user corrects you about how something works, how a tool should be used, or how this environment is
configured, **always ask whether the correction should be documented** in `~/.agents/docs/`.

- Review the existing docs to find the best fit for the new information.
- If an existing document covers the topic, propose integrating the learning there.
- If no existing document is a good fit, propose creating a new themed document and linking it from the
  Specialized Topics section of the relevant AGENTS.md file(s).
- Keep documentation lean: capture the principle or rule, not a transcript of the conversation.

The goal is that future sessions benefit from every correction made in past sessions.

## Path Resolution Edge Case

**Important:** When checking if the current working directory is a git repository, be aware that paths
may look different but resolve to the same location via symlinks.
Always resolve paths to their canonical form (e.g., using `readlink -f`) before assuming two different-looking paths
are actually different locations.
This prevents incorrectly treating the home directory as a regular git repository when it's actually managed by YADM.

<!-- BEGIN BEADS INTEGRATION v:1 profile:full hash:f65d5d33 -->

## Issue Tracking with bd (beads)

**IMPORTANT**: This project uses **bd (beads)** for ALL issue tracking. Do NOT use markdown TODOs, task lists, or other tracking methods.

### Why bd?

- Dependency-aware: Track blockers and relationships between issues
- Git-friendly: Dolt-powered version control with native sync
- Agent-optimized: JSON output, ready work detection, discovered-from links
- Prevents duplicate tracking systems and confusion

### Quick Start

**Check for ready work:**

```bash
bd ready --json
```

**Create new issues:**

```bash
bd create "Issue title" --description="Detailed context" -t bug|feature|task -p 0-4 --json
bd create "Issue title" --description="What this issue is about" -p 1 --deps discovered-from:bd-123 --json
```

**Claim and update:**

```bash
bd update <id> --claim --json
bd update bd-42 --priority 1 --json
```

**Complete work:**

```bash
bd close bd-42 --reason "Completed" --json
```

### Issue Types

- `bug` - Something broken
- `feature` - New functionality
- `task` - Work item (tests, docs, refactoring)
- `epic` - Large feature with subtasks
- `chore` - Maintenance (dependencies, tooling)

### Priorities

- `0` - Critical (security, data loss, broken builds)
- `1` - High (major features, important bugs)
- `2` - Medium (default, nice-to-have)
- `3` - Low (polish, optimization)
- `4` - Backlog (future ideas)

### Workflow for AI Agents

1. **Check ready work**: `bd ready` shows unblocked issues
2. **Claim your task atomically**: `bd update <id> --claim`
3. **Work on it**: Implement, test, document
4. **Discover new work?** Create linked issue:
   - `bd create "Found bug" --description="Details about what was found" -p 1 --deps discovered-from:<parent-id>`
5. **Complete**: `bd close <id> --reason "Done"`

### Quality

- Use `--acceptance` and `--design` fields when creating issues
- Use `--validate` to check description completeness

### Lifecycle

- `bd defer <id>` / `bd supersede <id>` for issue management
- `bd stale` / `bd orphans` / `bd lint` for hygiene
- `bd human <id>` to flag for human decisions
- `bd formula list` / `bd mol pour <name>` for structured workflows

### Auto-Sync

bd automatically syncs via Dolt:

- Each write auto-commits to Dolt history
- Use `bd dolt push`/`bd dolt pull` for remote sync
- No manual export/import needed!

### Important Rules

- ✅ Use bd for ALL task tracking
- ✅ Always use `--json` flag for programmatic use
- ✅ Link discovered work with `discovered-from` dependencies
- ✅ Check `bd ready` before asking "what should I work on?"
- ❌ Do NOT create markdown TODO lists
- ❌ Do NOT use external issue trackers
- ❌ Do NOT duplicate tracking systems

For more details, see README.md and docs/QUICKSTART.md.

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**

- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds

<!-- END BEADS INTEGRATION -->
