# Developer Directory

All cloned repositories live under `~/Developer` following a **go-style** path convention:

```
~/Developer/<forge-host>/<owner>/<repo>
```

## Examples

- `~/Developer/github.com/pedropombeiro/opencode-plugins`
- `~/Developer/gitlab.com/pedropombeiro/playground`

## Forge conventions

- **github.com** — Personal and open-source projects.
- **gitlab.com** — Mix of personal projects and GitLab work repositories (work repos use org-level owners, not `pedropombeiro`).

## Finding a repo

To locate a cloned project, construct the path from the remote URL:

```
https://github.com/pedropombeiro/opencode-plugins
→ ~/Developer/github.com/pedropombeiro/opencode-plugins
```

If the exact owner is unknown, list candidates:

```bash
ls ~/Developer/github.com/
```
