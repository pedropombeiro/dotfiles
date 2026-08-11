# Renovate Bot

## Configuration

**Main config**: `~/.renovaterc.json`

**Validate changes**: `yadm enter hk check --step renovate-config-validator`

## Managers Configured

| Manager          | Files                                           | Purpose              |
| ---------------- | ----------------------------------------------- | -------------------- |
| `github-actions` | `.github/workflows/*.yml`                       | Action versions      |
| `pre-commit`     | `.pre-commit-config.yaml` (dead — see below)    | Hook versions        |
| `mise`           | `.config/mise/config.toml##*`, `conf.d/*.toml*` | Tool versions        |
| `custom.regex`   | mise configs                                    | GitHub backend tools |

> The `pre-commit` manager and its two `packageRules` in `~/.renovaterc.json` are dead:
> hk replaced pre-commit and `.pre-commit-config.yaml` no longer exists. Harmless, but
> safe to drop from the config.

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
