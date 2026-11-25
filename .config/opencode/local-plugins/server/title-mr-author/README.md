# title-mr-author

A Work-only OpenCode server plugin that names sessions after the GitLab item they
work on. Forgekeeper adds the issue and MR references, such as `[#123, !456]`, in
front of these titles.

## Behavior

- **Issue sessions**: when the first message asks to address, fix, implement,
  resolve, or work on a GitLab.com issue, work item, or epic, the session takes
  the item's title.
- **MR review sessions**: when the first message asks to review a GitLab.com MR,
  the title model writes `@<author> - Review <short topic>`.
- **Explicit renames**: the `rename_issue_session` and `rename_mr_review_session`
  tools apply the same rules to an existing session and keep its Forgekeeper
  prefix.

The plugin looks up titles and authors with `glab`. When a lookup fails,
OpenCode generates its usual title.

## Tests

Run the tests from this directory:

```sh
mise exec bun -- bun test
```
