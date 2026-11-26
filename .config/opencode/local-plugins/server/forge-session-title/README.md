# forge-session-title

An OpenCode server plugin that names sessions after the GitHub or GitLab item
they work on. Forgekeeper adds the issue and PR/MR references, such as
`[#123, !456]`, in front of these titles.

## Behavior

- **Issue sessions**: when the first message asks to address, fix, implement,
  resolve, or work on a GitHub issue or GitLab issue, work item, or epic (by
  full URL, `owner/repo#123`, or `#123` in a checkout), the session takes the
  item's title.
- **PR/MR review sessions**: when the first message asks to review a GitHub PR
  or GitLab MR (by full URL, `group/project!123`, `!123`, `owner/repo#42`, or
  `#42` in a GitHub checkout), the plugin passes the author and PR/MR title to
  the title model so it writes `@<author> - Review <short topic>`.
- **Explicit renames**: the `rename_issue_session` and
  `rename_mr_review_session` tools apply the same rules to an existing session,
  accept both full URLs and shorthand references, and keep any Forgekeeper
  prefix. When `topic` is omitted (or `"merge request"` / `"pull request"`),
  `rename_mr_review_session` falls back to the PR/MR title.

## Architecture

- `src/forges.ts`: `Forge` interface and `ForgeRegistry` for remote resolution
  (`origin` -> `upstream` -> others), reference parsing, and cross-forge
  fallback.
- `src/gitlab.ts`: `GitLabForge` adapter backed by `glab` (REST for MRs,
  GraphQL `namespace.workItem` for issues, work items, and epics).
- `src/github.ts`: `GitHubForge` adapter backed by `gh` (REST for PRs and
  issues).

When a lookup fails, OpenCode generates its usual title.

## Tests

Run the tests from this directory:

```sh
mise exec bun -- bun test
```
