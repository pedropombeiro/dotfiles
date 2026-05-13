# Personal Lessons Learned

Actionable corrections accumulated from user feedback.
Subject-specific lessons live in their `.local.md` counterparts (e.g. `testing.local.md`, `code-style.local.md`).

## General

- `CLAUDE.local.md` and this file are loaded explicitly via `opencode.jsonc` instructions. Load other `.ai/<topic>.md` modules (and matching `.local.md`) on demand based on the task.

## Work Items (MRs, Issues, Epics)

- Do not post comments directly on MRs, issues, or epics. Only update descriptions, labels, and metadata.
- Do not assign reviewers unless the user explicitly asks — leave reviewer selection to the user.
- When replying in-thread with `gitlab_create_discussion`, verify the `discussion_id` belongs to the specific thread containing the target note — match by note ID from `gitlab_list_discussions`, not by proximity in the listing.
- Plan-mode approval (e.g. answering Q1/Q3/Q5) is approval to proceed with the plan, NOT approval to post comments. Always draft the final comment text in chat and wait for an explicit "post it" / "go ahead" before calling `gitlab_create_note` or `gitlab_create_discussion`.

