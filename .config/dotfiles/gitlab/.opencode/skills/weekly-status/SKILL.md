---
name: weekly-status
description: Write a weekly status report on a GitLab issue or epic using a fixed template. Use when the user asks for a "weekly status", "weekly update", "status review", or "status update" on a specific work item.
license: MIT
compatibility: opencode
metadata:
  audience: developers
  author: pedropombeiro
  workflow: gitlab
---

# Weekly status

Write a weekly status comment on a GitLab issue or epic using the template below.

## When to use

The user mentions any of:

- "weekly status", "weekly update", "weekly review"
- "status update for #N" or "status update on &N"
- "status review for [work item]"

## When NOT to use

- The target is a merge request. MRs have their own review-state machinery; do
  not post a weekly status comment on an MR.
- The target is a closed issue or epic without a clear wrap-up intent. Ask the
  user whether they want a final closing comment instead.

## Template

Read [`assets/template.md`](assets/template.md) and use it verbatim,
including the comments. Fill in the bullets and check exactly one
confidence box.

## Drafting rules

- Audience is a manager. Keep each bullet terse and high-signal.
- Skip process noise: review-suggestion cycles, lint runs, rebase mechanics,
  draft iteration count, mode switches, tool-call details.
- Each `Progress this week` bullet describes an outcome, not a step. Prefer
  "MR !X opened with Y" over "Iterated on the description for MR !X".
- `What's next` lists concrete, named items (MR IIDs, issue numbers).
- Wrap GitLab usernames in backticks (`` `username` ``) so they are not
  pinged.
- Link issues and merge requests by IID. Inside `gitlab-org/gitlab`, `!IID`
  and `#IID` short references render as links. For epics or cross-project
  references, use the full URL.
- Pick exactly one confidence checkbox. Leave the other two unchecked but
  visible. Do not remove any line from the Confidence section.
- The `/health_status` argument must match the chosen confidence checkbox.

### Confidence ↔ `/health_status` mapping

| Checkbox                              | `/health_status` value |
|---------------------------------------|------------------------|
| 🔴 At risk - may not make it          | `at_risk`              |
| 🟡 Some concerns - watching closely   | `needs_attention`      |
| 🟢 On track - confident we'll deliver | `on_track`             |

## Posting workflow

1. Draft the comment in chat. Do not call `gitlab_create_note` yet.
2. Wait for the user's explicit "post it" or "go ahead" before posting. Mode
   approvals (plan mode → build mode, answering questions) do **not** count
   as posting approval.
3. Post via `gitlab_create_note`:
   - For an issue: `resource_type=issue`, `project_id=<group/project>`,
     `iid=<issue-iid>`, `body=<final-text>`.
   - For an epic: `resource_type=epic`, `group_id=<group>`,
     `iid=<epic-iid>`, `body=<final-text>`.
4. Verify the response includes `commands_changes.health_status` so the
   `/health_status` quick action took effect.

## Examples

### Good

Tight, manager-readable, one outcome per bullet:

```markdown
## Status Update

**Progress this week:**
- Filed issue and opened MR !235898 adding two new pages under
  `doc/development/agent_principles/` and a cross-link from
  `feature_development.md`.
- MR is mergeable, pipeline green, all discussions resolved.

**What's next:**
- Land MR !235898 after `dgruzd` review.
- Follow-up: back-link from `.ai/principles/README.md` and
  `.ai/principles/manifest.yml` to the new docs page, landing on
  !235272.

**Blockers:**
- None

**Confidence for current milestone:**
- [ ] 🔴 At risk - may not make it
- [ ] 🟡 Some concerns - watching closely
- [x] 🟢 On track - confident we'll deliver

/health_status on_track
/cc @cheryl.li
```

### Bad

Process-heavy, low-signal, would not help a manager:

```markdown
**Progress this week:**
- Filed the issue on 2026-05-13 and opened the MR.
- Applied three Duo Code Review suggestions on opening paragraphs and
  validation wording; modified two to preserve the planning-time framing
  and accepted one verbatim. All three suggestion threads resolved.
- Restructured the rule-authoring guidance into two audiences after
  feedback that imperative phrasing applies only to baseline files.
- Triggered the `review-docs-deploy` Review App. Preview URLs: ...
- Vale and `markdownlint-cli2` both pass.
```

Why it fails: review-iteration mechanics, lint pass/fail, and Review App
trigger details are process noise, not outcomes a manager needs to track.

## Asking the user

If any of these are unknown, ask before drafting:

- The work item to report on (issue IID or epic IID + group).
- Which milestone the work belongs to, if it isn't obvious from the work
  item's metadata.
- Confidence level for the current milestone (🔴 / 🟡 / 🟢).
- Override for the default `/cc` handle (`@cheryl.li`).
