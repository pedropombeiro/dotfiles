# Git - Personal Lessons

- Once a reviewer has seen a commit (it has been pushed and reviewed), do NOT rewrite it (amend/rebase/squash) without explicit user approval. Add follow-up commits instead. If a hard blocker forces a history rewrite (e.g. Danger rejects a commit message), ask first.
- It is fine to keep separate, discrete commits across review rounds; the MR squashes on merge. Put the final squash message on the first commit.
