---
name: resolve-vent
description: Resolve friction items recorded by the OpenCode `vent` tool, such as `pedropombeiro/work-friction` work items or `pedropombeiro/agent-friction` GitHub issues. Use when asked to address, fix, triage, or close a vent, a friction item, a work-friction work item, or an agent-friction issue.
---

# Resolve vent

A vent records friction that an agent hit in a tool, doc, skill, permission, or
workflow. Fix the cause in the dotfiles so the next agent doesn't hit the same
friction.

## Where vents live

- **GitLab**: confidential work items in `pedropombeiro/work-friction`, under the
  [friction epic](https://gitlab.com/groups/gitlab-org/-/epics/24897). Work machines
  only.
- **GitHub**: private issues in
  [`pedropombeiro/agent-friction`](https://github.com/pedropombeiro/agent-friction)
  for personal and dotfiles friction, labeled `agent-friction`.

The "Vent routing" section of `~/.agents/docs/opencode.md` decides where new vents go.

## Workflow

1. **Set the target.** For a GitLab work item or GitHub issue, call
   `set_session_target` with its URL before reading it.
1. **Read the item.** For GitLab, read the description and notes with
   `gitlab_get_work_item` and `gitlab_get_work_item_notes`. For GitHub, run
   `gh issue view <number> -R pedropombeiro/agent-friction --comments`. The
   `Session metadata` block records the directory, repository, branch, and
   session ID.
1. **Find the original session.** Call `search_sessions` with that `session_id`, a
   query taken from the friction text, and `include: ["tools"]` to see the failing
   call and its error. Note what the agent was doing, which call failed, and
   whether the user had approved the action.
1. **Look for duplicates.** List open items in the project with
   `gitlab_list_issues` (`gitlab_list_work_items` currently fails with GraphQL
   schema type errors on `WorkItemTypeEnum` and `IssuableState`), or with
   `gh issue list -R pedropombeiro/agent-friction` for GitHub.
   Resolve items with the same root cause together, and set all of them as
   session targets.
1. **Find the root cause.** Reproduce the failure, or confirm it in the config,
   plugin code, skill, or doc involved. Permission rules live in
   `~/.config/opencode/opencode.json##template`. Then decide whether the behavior
   is intended:
   - **Intended**, such as a deliberate deny rule or guard: keep it, and document
     the supported workflow where the agent reads it before hitting the friction.
   - **Unintended**: fix the config, plugin, script, or doc.

   Follow the Continuous Learning rules in `AGENTS.md`. A rule the agent needs
   before acting belongs in `~/.config/opencode/AGENTS.md##template`; a procedure
   belongs in `~/.agents/docs/` or a skill. When the fix involves a real choice,
   ask with the `question` tool before building it.
1. **Review the fix in Plannotator.** Build the change as one patch, following
   steps 1-5 of the "Protected OpenCode config" section in
   `~/.agents/docs/opencode.md`, and review it with `plannotator review --patch-file`. After approval:
   - If the patch touches `~/.config/opencode/`, give the user the apply commands
     from that section.
   - Otherwise, apply it with `yadm apply` from `~` and confirm the result.

   Run any tests that cover the changed files, and `yadm alt` after changing a
   `##template` file.
1. **Close out after approval.** Once the fix is in place:
   1. Draft a closing comment that states the root cause, what changed, and the
      changed file paths. Read `~/.agents/docs/writing-style.md` first.
   1. Ask with the `question` tool whether to post the comment and close the item.
      Neither work item notes nor issue comments have a draft state, so posting
      publishes immediately.
   1. For GitLab, post the comment with `gitlab_create_work_item_note`, then close
      the item with `gitlab_update_work_item` and `state_event: "close"`. For
      GitHub, run
      `gh issue close <number> -R pedropombeiro/agent-friction --comment <text>`.
      Close each duplicate with a short comment that links the main item.
   1. Report which files are uncommitted. Don't commit unless the user asks.
