# Pre-commit

Pre-commit hooks and code quality checks.

## Configuration

**Main config**: `~/.pre-commit-config.yaml`

## Running Hooks

```bash
# In YADM-managed repo (home directory)
yadm enter pre-commit run --all-files

# Run specific hook
yadm enter pre-commit run <hook-id> --all-files

# Run with auto-fix (manual stage)
yadm enter pre-commit run --all-files --hook-stage manual
```

## Configured Hooks

| Hook                      | Purpose                                             |
| ------------------------- | --------------------------------------------------- |
| pre-commit-hooks          | Basic file checks (trailing whitespace, YAML, JSON) |
| shellcheck                | Shell script linting                                |
| yamllint                  | YAML linting                                        |
| stylua                    | Lua formatting                                      |
| prettier                  | JSON/Markdown/YAML formatting                       |
| standardrb                | Ruby linting                                        |
| markdownlint-cli2         | Markdown linting                                    |
| editorconfig-checker      | EditorConfig validation                             |
| zsh-syntax-check          | Zsh syntax validation                               |
| mise-fmt                  | Mise configuration formatting                       |
| renovate-config-validator | Renovate config validation                          |

## Mise Task Integration

```bash
mise run dotfiles:lint    # Run all hooks
mise run dotfiles:fix     # Run with manual fixes
```

## Common Issues

**Hook fails to install:**

```bash
pre-commit clean
pre-commit install-hooks
```

**Stale hooks after update:**

```bash
pre-commit autoupdate
```

## Adding New Hooks

1. Add hook to `~/.pre-commit-config.yaml`
2. Run `pre-commit autoupdate` to get latest versions
3. Test with `yadm enter pre-commit run <new-hook> --all-files`

## Guidelines

- Keep hooks fast (use native tools when possible)
- Group related hooks together in config
- Use `stages: [manual]` for slow or optional hooks
- Hook versions are updated via Renovate bot
