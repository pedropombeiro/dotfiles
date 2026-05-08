# Personal Lessons Learned

Actionable corrections accumulated from user feedback.
Subject-specific lessons live in their `.local.md` counterparts (e.g. `testing.local.md`, `code-style.local.md`).

## General

- Always read and internalize `CLAUDE.local.md` and `.ai/AGENTS.md` at the start of every session, then load only the task-relevant `.ai/` modules.

## Work Items (MRs, Issues, Epics)

- Do not post comments directly on MRs, issues, or epics. Only update descriptions, labels, and metadata.
- Do not assign reviewers unless the user explicitly asks — leave reviewer selection to the user.
- When replying in-thread with `gitlab_create_discussion`, verify the `discussion_id` belongs to the specific thread containing the target note — match by note ID from `gitlab_list_discussions`, not by proximity in the listing.

