---
description: Commit changes in logical commits and push
model: gitlab/duo-chat-gpt-6-luna
---

Commit all changes in discrete, logical commits and push to the remote. Follow
`~/.agents/docs/scm.md` for commit conventions, grouping, and quiet output.

## Workflow

1. In addition to the files you have worked on, analyze changes with `status` and `diff` commands
2. Review recent commit messages for style reference
3. Group related files into logical commits, keeping configuration, code with its tests, and
   documentation in separate commits
4. Pull with rebase (`git pull --rebase`) to incorporate any remote changes
5. Push the changes to remote
