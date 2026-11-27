# confidential-guard

Local OpenCode server plugin that keeps routine work on upstream models while
automatically switching and locking confidential GitLab or RED production
sessions to GitLab Duo (`providerID: "gitlab"`).

## Triggers

A session is locked to GitLab Duo when any of the following occur:

1. **Ancestor, fork, or Forgekeeper owner inheritance**: a parent session
   (`parentID`), fork source (`fork.sessionID`), or Forgekeeper linked owner
   (`metadata.forgekeeper.linked.owner`) is already locked. Subagents
   (`parentID`) also propagate locks up to their parent/root session;
   Forgekeeper linked sessions inherit from their owner without locking or
   switching the owning session.
2. **Confidential repository or branch remote**: the working directory, `origin`
   remote, or current branch's tracking remote points to
   `gitlab-org/security/*`, `gitlab-com/gl-security/*`, or
   `pedropombeiro/work-friction`. Shared checkouts such as `$GDK_ROOT/gitlab`
   that keep an idle `security` remote stay on upstream models while working on
   public branches.
3. **Prompt, branch, and Forgekeeper target preflight** (`session.hook("prompt")`):
   inspects GitLab URLs/shorthands in the prompt, `forgekeeper-session-target`
   instructions, and `<username>/<issue-iid>/...` branch names via cached
   `glab api` checks for `"confidential": true`, `~security` (without
   `~security-fix-in-public`), or MRs linked to confidential issues. Unverified
   references fail closed to GitLab Duo without caching as public. Switches the
   session (and any parent session) before the turn resolves its
   model.
4. **Pre-execution RED/confidential tools** (`tool.hook("execute.before")`):
   classifies `esquery`, `esquery-staging`, `incident_io`,
   `dblab`/`postgresai`/`pgai`, `gitlab_*(vulnerabilit|audit_event)*`,
   cross-directory access into confidential checkouts, and GitLab API/CLI calls
   targeting confidential projects, issues, work items (`work_item_id` /
   `work_item_iid`), MRs, or epics on all providers—locking the session when
   already on Duo and blocking + switching when the active turn started on a
   non-`gitlab` model.
5. **Post-execution confidential responses** (`tool.hook("execute.after")`):
   redacts confidential or security-labeled GitLab/vent tool output (and
   switches the session on `set_session_target`) before the payload can be sent
   to an upstream model.
6. **Request backstops** (`context`, `generate`, `compaction`, `title`): blocks
   any non-`gitlab` LLM request on a locked session and routes confidential
   title generation through `gitlab/duo-chat-gpt-6-luna`.
7. **Post-compaction re-evaluation** (`session.compaction.ended` and active
   context reconciliation): rescans the compacted checkpoint (`<summary>` and
   `<recent-context>`), remaining post-compaction messages/tool calls, repository
   checkout, branch, and Forgekeeper session target. Pre-compaction findings are
   replaced with the post-compaction scan (preserving previously dismissed
   prompt findings). When no active findings remain, the session unlocks and
   switches back to the agent's configured default model.

## Inspect and dismiss a finding

Run `/confidential-status` in the terminal session to see the recorded reasons
for a lock. The command opens a local dialog without sending a prompt to a model.
Select a GitLab issue, work item, or merge request finding and choose
**Recheck GitLab** to see the current assessment without using cached results.
Rechecking doesn't clear the finding.

If a reference in a prompt was incidental, choose **Mark as false positive**
on that finding and confirm. For GitLab items, GitLab must currently report
the item as public. Only dismiss a finding if the conversation is safe to send
to the next model. The action applies to this session and this finding. Future
prompts and tool calls still go through the guard.

When no active findings remain, use `/models` to choose another provider.
Findings from tools, checkouts, branches, session targets, or related sessions
can't be dismissed. If an older lock shows **History incomplete**, review the
entire conversation, including tool results, before choosing **Clear legacy
lock after reviewing session**. This clears only the selected session's legacy
finding. Other findings and future guard checks still apply.

## Duo Model Mapping

Target Duo models are configured via plugin `options.models` (expanded from
`OPENCODE_DUO_PLAN_MODEL`, `OPENCODE_DUO_BUILD_MODEL`, and
`OPENCODE_DUO_FAST_MODEL` in `~/.config/mise/conf.d/opencode.toml`), falling
back to the matching `OPENCODE_DUO_*` environment variables and then the
built-in Duo defaults. Non-`gitlab` values are ignored.

| Agent | Configuration Source |
| :--- | :--- |
| `plan` (and default) | `options.models.plan` / `OPENCODE_DUO_PLAN_MODEL` |
| `build` | `options.models.build` / `OPENCODE_DUO_BUILD_MODEL` |
| `explore` | `options.models.explore` / `OPENCODE_DUO_FAST_MODEL` |
| `title` | `options.models.title` / `OPENCODE_DUO_FAST_MODEL` |
| `general` | Inherits parent's `gitlab/*` model (falls back to `plan`) |

## Tests

```sh
mise exec bun -- bun test
```
