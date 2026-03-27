# Workflow Reference

Use this reference when drafting PRs or issues and you need the detailed workflow checks.

## Pull Request Prep

Before creating a PR, check:

- current branch name and tracking status
- whether the branch is already pushed
- recent commit style in the repo
- the full diff against the base branch, not just the latest commit

## Multi-line Bodies

Prefer heredocs for PR and issue bodies:

```bash
gh pr create --title "feat: add feature" --body "$(cat <<'EOF'
## Summary
- Explain the user-facing change
- Note validation or follow-up details
EOF
)"
```

If you truly need a temp file, use `$TMPDIR`.

## Agent Guidelines

1. Use `gh` CLI rather than raw GitHub HTTP calls
2. Use `gh api` for endpoints not covered by first-class commands
3. Read issue or PR context before implementing
4. Check project templates before drafting bodies
5. Reference related issues and PRs properly in commit and PR text
