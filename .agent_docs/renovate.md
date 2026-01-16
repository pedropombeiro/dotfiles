# Renovate Bot

## Configuration Files

The Renovate config typically lives at the root of the repository under `.renovaterc.json`.

After making changes, validate with: `pre-commit run renovate-config-validator --all-files` (prefixing with `yadm enter`
if running on a YADM-managed repo).

## When to Reference This

- When working with dependency updates
- When modifying or creating Renovate configuration
- When troubleshooting automated dependency PRs
- `packageRules` in the configuration file should be ordered from generic to specific
