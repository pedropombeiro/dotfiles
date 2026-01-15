# Push Command

Commit all changes in discrete, logical commits and push to the remote.

## Workflow

1. In addition to the files you have worked on, analyze changes with `status` and `diff` commands
2. Review recent commit messages for style reference
3. Group related files into logical commits (same feature, bug fix, or refactor)
4. Create commits for each group with clear messages
5. Pull with rebase (`git pull --rebase`) to incorporate any remote changes
6. Push the changes to remote

## Git command guidelines

Commit and push changes silently first (`> /dev/null 2>&1`), only show output on failure

## Grouping Guidelines

- Each commit should represent a single logical change
- Keep configuration separate from code changes
- Keep tests with their corresponding implementation
- Keep documentation separate from code changes
