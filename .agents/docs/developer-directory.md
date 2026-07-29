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

## Global agent skills

Skills under `~/.agents/skills/` are symlinks into clones here, so `git pull` in the
clone upgrades the skill and nothing needs vendoring into the dotfiles repo:

| Clone                                         | Provides                                                                                 |
| --------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `gitlab.com/gitlab-org/ai/skills`             | `handoff`, `write-large-file`, `glab-glql`, `gitlab-babysit-mr`, `gitlab-pipeline-watch` |
| `gitlab.com/gitlab-org/orbit/knowledge-graph` | `orbit` (canonical home per the skill's own `references/maintaining.md`)                 |

The symlinks themselves are deliberately left untracked by YADM — the upstream clone is
the source of truth. Only genuinely local skills get tracked.
