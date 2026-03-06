---
description: Post weekly status updates on assigned milestone issues
model: gitlab/duo-chat-opus-4-6
---

Post weekly status updates on all GitLab issues assigned to me for the current milestone.

## Context files

Read these files for reference before starting:

- @.gitlab/duo/chat-rules.md -- contains the weekly update template and formatting rules
- @~/.agents/docs/writing-style.md -- Pedro's writing style conventions

## Workflow

1. **Determine the current milestone**: Use today's date to figure out the current GitLab milestone.
   GitLab milestones follow the `YY.MM` pattern (e.g. `18.10`). Each milestone starts ~2 weeks
   before the release date (around the 3rd Thursday of the month). Use `gitlab_list_issues` with
   a candidate milestone to confirm it exists. If unsure, try the milestone matching the current
   month and year.

2. **Fetch assigned issues**: Use `gitlab_list_issues` with `scope: assigned_to_me`,
   `state: opened`, `milestone: <current>`, and `project_id: gitlab-org/gitlab` to get all
   open issues assigned to me in the current milestone.

3. **Fetch related MRs**: Use `gitlab_list_merge_requests` with `scope: created_by_me` for
   both `state: opened` and `state: merged` (limit 10 for merged). Correlate MRs to issues
   by matching branch names, issue references in descriptions, or `Closes #NNN` / `Part of #NNN`.

4. **Assess health status for each issue**: Based on MR states, determine confidence:
   - **on_track** (:green_circle:): MR merged or in review with no blockers, plenty of time before code freeze
   - **needs_attention** (:yellow_circle:): MR in review but pending approval, or external dependency
     (e.g. waiting for staging deploy verification), or timeline is getting tight
   - **at_risk** (:red_circle:): Multiple MRs still need review/approval before code freeze,
     or no MR submitted yet with little time remaining, or significant blockers

5. **Draft updates**: For each issue, draft a comment using the weekly update template from
   `chat-rules.md`. Keep bullet points succinct (1 line each). Reference MRs with `!NNN` notation.
   Include the `/health_status` and `/cc @golnazs` quick actions at the end.
   Skip issues that are pure feature flag rollout tracking (no code work) unless they have
   independent progress to report -- in that case, note they are blocked on the parent issue.

6. **Present drafts for review**: Show ALL drafted updates to the user in a single message,
   clearly labeled by issue number and title. Ask the user to confirm or request edits before
   posting.

7. **Post updates**: After user confirmation, use `gitlab_create_note` with
   `resource_type: issue`, `project_id: gitlab-org/gitlab`, and the appropriate `iid` to post
   each update. Report back with links to the posted comments.

## Rules

- When outputting GitLab user names in the draft previews, wrap them in backticks so they are
  not mentioned during preview
- Use `!NNN` for MR references and `#NNN` for issue references
- Keep each bullet point to a single concise line
- Do not post without explicit user confirmation
- If an issue has no meaningful progress to report, ask the user whether to skip it or post
  a minimal update
