---
name: handoff
description: Save a session handoff so a fresh agent can continue the work. Use when the user says hand off, wrap up, save context, continue later, or pick this up in a new session.
license: MIT
---

# Handoff

Write a handoff document that lets a fresh agent continue the current work.
Anchor it to durable artifacts and record the next actionable step.

## Principles

- **Reference existing artifacts.** Link relevant issues, pull or merge requests,
  commits, files, and notes by URL or path. For changing state, include a command
  to retrieve it again rather than copying a snapshot.
- **Gather current state.** In a repository, check the branch, recent commits,
  and working-tree status. Use `yadm` for YADM-managed dotfiles. Use the relevant
  forge CLI when needed. For non-repository tasks, record the files, tools, and
  outstanding actions instead.
- **Keep useful context.** Include the goal, completed work, decisions, next
  steps, blockers, key files, and relevant skills. Skip sections that do not apply.
  Adapt [the example template](assets/handoff-template.md) to the task.
- **Redact secrets.** Never reproduce credentials or sensitive personal data.
  Replace them with `[REDACTED]` without quoting their original values.

## Save the handoff

1. Honor an explicit destination supplied by the user.
1. Otherwise, use `./tmp/handoff-<topic>.md` if that directory is already ignored
   by the repository. Check with `git check-ignore` or the YADM equivalent.
1. If there is no suitable ignored directory or no repository, use a temporary
   file in the environment's permitted temporary directory.
1. Tell the user the saved path so they can load it in the next session.

## Attribution

Adapted from the GitLab AI skills `handoff` v0.5.0 and the
[handoff skill](https://github.com/mattpocock/skills/tree/main/skills/productivity/handoff)
by Matt Pocock, Copyright (c) Matt Pocock, MIT License.
This platform-neutral adaptation is maintained in the YADM dotfiles repository.
