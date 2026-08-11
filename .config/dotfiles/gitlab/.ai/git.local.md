# Git - Personal Lessons

- Once a reviewer has seen a commit (it has been pushed and reviewed), do NOT rewrite it (amend/rebase/squash) without explicit user approval. Add follow-up commits instead. If a hard blocker forces a history rewrite (e.g. Danger rejects a commit message), ask first.
- It is fine to keep separate, discrete commits across review rounds; the MR squashes on merge. Put the final squash message on the first commit.
- Branch naming: use `<username>/<issue-id>/<branch-name>` (the `git-helpers` skill convention), NOT the `feature/`, `fix/`, `<issue-number>-` patterns in `.ai/git.md`. Those are the upstream-contributor defaults; the stacked-branch helpers (parent detection, chained rebase) parse the username/issue form and break without it.
