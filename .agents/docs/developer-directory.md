# Developer Directory

All cloned repositories live under `~/Developer` following a **go-style** path convention:

```
~/Developer/<forge-host>/<owner>/<repo>
```

> **macOS only.** The QTS NAS has no `~/Developer`; see "QTS NAS" below.

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

## QTS NAS

The NAS does not use `~/Developer` or the go-style nesting. Clones live **flat** under
`~/opt`:

```
~/opt/<repo>
```

Examples: `~/opt/vscode-home-assistant`.

`~/opt` also holds non-repo build support (e.g. `~/opt/qts-glibc-shim`), so treat it
as "local software", not purely a clone root. The skill symlinks described below are a
macOS arrangement and are not present there.

## Global agent skills

Some skills link into clones here. Updating the clone updates those skills.
Shared skills live in `~/.agents/skills`; work-only skills live in
`~/.agents/skills.work` and load only through the Work configuration.

- `gitlab.com/gitlab-org/ai/skills`: shared `write-large-file`, plus work-only
  `glab-glql`, `gitlab-babysit-mr`, and `gitlab-pipeline-watch`.
- `gitlab.com/gitlab-org/orbit/knowledge-graph`: work-only `orbit`.
- `github.com/pinchtab/pinchtab`: shared `pinchtab`.

Upstream repository links are generally untracked. Locally maintained skills,
including the generic `handoff`, and installer-managed snapshots are tracked by
YADM. See [skill loading](opencode.md#skill-loading) for setup and updates.
