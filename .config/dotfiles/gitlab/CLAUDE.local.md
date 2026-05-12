# Personal AI Agent Instructions

For non-trivial repo work, load `.opencode/skills/repo-bootstrap/SKILL.md` to assemble the active
repo-local rules before broad exploration or command execution. Consult `.ai/README.md` for the
module map and load matching `.ai/<topic>.md` (+ `.local.md` counterpart) on demand.

## Glean MCP

**IMPORTANT:** When searching for GitLab documentation (docs.gitlab.com), runbooks, handbook
content, or any company knowledge, **always use the Glean MCP first** — do NOT fall back to
`webfetch`, `gitlab_documentation_search`, or local `grep`/`Grep`/`Glob`/`git grep` for
documentation lookups. These local tools are a last resort for this purpose; Glean is faster,
more comprehensive, and indexes sources that local tools cannot reach.

- **Prefer `chat`** for questions that need synthesis or reasoning across multiple sources
  (e.g. "how does feature X work?", "what's the process for Y?"). A single `chat` call is
  often more efficient than multiple parallel `search` calls.
- **IMPORTANT:** `search` returns very large results that consume significant context. Always
  try `chat` first — it returns summarized results that are much more efficient. Only fall
  back to `search` when you specifically need raw, unprocessed document results.
- `search` supports filtering by app (e.g. `gitlab`, `slack`, `gdrive`), date, author,
  and channel.
- Glean also indexes Slack, Google Docs, email, and more — use it to gather additional
  context when information is missing from documentation.

## GDK Update Rule

**Never update from remote manually** — do not run `git pull`, `git fetch` + `git rebase`,
or `gdk update` directly. Always use `fgdku` instead; it handles fetching, rebasing all
branches, bundle install, migrations, GDK restart, and post-update cleanup in the correct
order. See the [GDK skill](.opencode/skills/gdk/SKILL.md) for how to run it.

## ClickHouse

For ClickHouse tables, schemas, ingestion, or `CH` questions in this GitLab repo, load the
repo-local ClickHouse skill first: `.opencode/skills/clickhouse/SKILL.md`.

## Learning Protocol

When the user corrects you or points out a mistake:

1. Acknowledge the correction.
2. Decide whether it is repo-specific or global.
   - Repo-specific GitLab rules, conventions, or workflows belong in `.ai/*.local.md`.
   - Cross-repo tooling or environment rules belong in `~/.agents/docs/` via the global continuous-learning flow.
3. If it is repo-specific, determine which category it falls into: code-style, testing, git, database, code-review, merge-requests, or general.
4. Append a concise, actionable repo-specific lesson to the corresponding `.ai/<category>.local.md` file.
   - If the file does not exist yet, create it with a `# <Category> - Personal Lessons` heading.
   - For general lessons that do not fit a specific category, use `.ai/lessons-learned.local.md`.
5. Keep entries short (1-2 lines), framed as "Do X" or "Don't do Y" rules.
6. Do not duplicate existing entries.

## Context Loading (Personal)

When loading a module from `.ai/` (for example, `.ai/testing.md`), also check for and load its `.local.md` counterpart
if it exists (for example, `.ai/testing.local.md`). Always load `.ai/lessons-learned.local.md` if it exists.
