# Renovate Bot

## Configuration

**Main config**: `~/.renovaterc.json`

**Validate changes**: `yadm enter hk check --step renovate-config-validator`

## Managers Configured

| Manager          | Files                                           | Purpose              |
| ---------------- | ----------------------------------------------- | -------------------- |
| `github-actions` | `.github/workflows/*.yml`                       | Action versions      |
| `mise`           | `.config/mise/config.toml##*`, `conf.d/*.toml*` | Tool versions        |
| `custom.regex`   | mise configs, `opencode.json##*`                | Backend tools, plugins |

## Prefixed Release Tags

Tools pinned to a bare version (`26.5.6`) cannot be compared against v-prefixed
upstream tags without `extractVersionTemplate` on the custom manager:

```json
"extractVersionTemplate": "^v?(?<version>.*)$"
```

Tags with a non-`v` prefix need a per-package `extractVersion` rule instead —
see the `ipinfo/cli` (`ipinfo-3.3.2`) and `orf/gping` (`gping-v1.20.4`) rules.
Match the backend generically (`^([a-z]+:)?owner/repo$`) so switching a tool
between `github:` and `aqua:` does not silently break its updates.

## Blocked Branches

Renovate freezes a branch when it contains a commit from an unrecognized author
(`branch.isModified() = true`), and reports it under **PR Edited (Blocked)** on
the Dependency Dashboard. Because these branches are grouped, one wedged branch
stalls every tool in its group.

Ticking the dashboard rebase checkbox only works if the branch still has an
**open PR**. With no open PR, Renovate logs `dependencyDashboardCheck=undefined`
and skips it; delete the remote ref instead and let the next run recreate it:

```
gh api -X DELETE repos/<owner>/<repo>/git/refs/heads/renovate/<branch>
```

Check the commit is already on `master` first — the same change is often
re-committed there separately, so tree hashes and patch-ids will differ.

## Adding Package Rules

Rules are evaluated in order; place specific rules after generic ones:

```json
{
  "description": "Clear description of what this rule does",
  "matchManagers": ["manager-name"],
  "matchPackageNames": ["package-name"],
  "matchFileNames": ["file-pattern"],
  "enabled": true,
  "automerge": false,
  "groupName": "group name"
}
```

### Common Matchers

| Matcher             | Example                                        |
| ------------------- | ---------------------------------------------- |
| `matchManagers`     | `["github-actions", "pre-commit", "mise"]`     |
| `matchPackageNames` | `["nodejs", "go"]`                             |
| `matchUpdateTypes`  | `["patch", "minor", "major", "pin", "digest"]` |
| `matchFileNames`    | `[".config/mise/config.toml##distro.qts"]`     |

### Common Actions

| Action              | Purpose                        |
| ------------------- | ------------------------------ |
| `enabled: false`    | Disable updates                |
| `automerge: true`   | Auto-merge when CI passes      |
| `groupName`         | Combine updates into single PR |
| `schedule`          | Limit when PRs are created     |
| `minimumReleaseAge` | Wait before updating           |

## Troubleshooting

- **PR not created**: Check for `enabled: false` rules, verify file patterns
- **Wrong version**: Verify regex in custom manager, check datasource
- **Auto-merge not working**: Verify status checks pass, check rule matches update type

## Guidelines

- Order packageRules from generic to specific
- Use clear `description` for each rule
- Test regex patterns before adding custom managers
- Pin security-sensitive dependencies (GitHub Actions)
- Use `minimumReleaseAge` for stability-critical tools
