# gitlab-session-title

A Work-only OpenCode server plugin that names sessions after the GitLab item they
work on. Forgekeeper adds the issue and MR references, such as `[#123, !456]`, in
front of these titles.

## Behavior

- **Issue sessions**: when the first message asks to address, fix, implement,
  resolve, or work on a GitLab.com issue, work item, or epic (by full URL,
  `group/project#123`, or `#123` in a GitLab checkout), the session takes the
  item's title.
- **MR review sessions**: when the first message asks to review a GitLab.com MR
  (by full URL, `group/project!123`, or `!123` in a GitLab checkout), the plugin
  passes the MR's author and title to the title model so it writes
  `@<author> - Review <short topic>`.
- **Explicit renames**: the `rename_issue_session` and `rename_mr_review_session`
  tools apply the same rules to an existing session, accept both full URLs and
  shorthand references, and keep any Forgekeeper prefix. When `topic` is omitted
  (or `"merge request"`), `rename_mr_review_session` falls back to the MR title.

The plugin resolves bare `#123` and `!123` references against the checkout's
`gitlab.com` Git remotes (preferring `origin`) and looks up titles and authors
with `glab`. When a lookup fails, OpenCode generates its usual title.

## Tests

Run the tests from this directory:

```sh
mise exec bun -- bun test
```
