# Agent Instructions

This file contains core instructions applicable to most tasks. For specialized topics, see the linked documents below.

## Specialized Topics

- [Shell](~/.agents/docs/shell.md) - Zsh configuration, zinit plugins, functions
- [SSH](~/.agents/docs/ssh.md) - Persistent NAS SSH sessions after macOS sleep
- [Bootstrap](~/.agents/docs/bootstrap.md) - YADM bootstrap scripts for system setup
- [Tmux](~/.agents/docs/tmux.md) - Configuration structure, plugins, and shell integration
- [OpenCode](~/.agents/docs/opencode.md) - Policy overrides and runtime behaviors
- [Architecture Decisions](~/.agents/docs/adr/) - ADRs for key tool choices

## Dotfiles (YADM)

**Always use `yadm` instead of `git`** when working with files in:

- `~/.config/`
- `~/.shellrc/`
- `~/.agents/docs/`
- `~/.claude/`
- Any dotfiles in `~` (the home directory is not a git repo)

Search tracked dotfiles with `yadm ls-files` and `yadm grep` to avoid traversing
unrelated home-directory files. Use filesystem searches when untracked or ignored
files matter.

## Externally installed skills

Treat skills installed by `npx skills` as vendored upstream snapshots. Track the
skill directories and `.agents/.skill-lock.json` with YADM so updates appear in
`yadm diff`, but keep `npx skills` as the update mechanism. Never reformat or
hand-edit these files, and confirm ownership before treating an untracked skill
as locally authored.

## Path Resolution Edge Case

Resolve symlinks before comparing repository paths (for example, with `readlink -f`)
so a different spelling of `$HOME` is still recognized as the YADM work tree.
