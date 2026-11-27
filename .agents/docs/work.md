# Work instructions

OpenCode's Work-specific global `AGENTS.md` instructs the agent to read this file.

- For GitLab documentation, runbooks, handbook content, or company knowledge,
  use Glean first via `tools["lazy-mcp"].invoke_command({ server: "glean_default", command_name, parameters })`.
  Prefer `chat` for synthesis and `search` for raw results:
  - `chat`: `{ message, _user_goal, context? }`
  - `search`: `{ query, _user_goal, ... }` with optional `app`, `updated`, `after`,
    `before`, `from`, `owner`, `sort_by_recency`, `num_results`, `cursor`
  - `read_document`: `{ urls, _user_goal, query?, page_selections? }`
  - `code_search`: `{ query, _user_goal, extension?, exhaustive? }`
- Forgekeeper linked sessions cannot answer permission prompts. If Glean is
  blocked, use checked-out sources for repository-local questions. For other
  questions, tell the owning session what to look up in Glean.
- For GitLab.com log questions in Kibana, load the `esquery` skill. Use the
  `esquery` MCP server for production (`log.gprd.gitlab.net`) and
  `esquery-staging` for staging (`nonprod-log.gitlab.net`). The skill's `pi`
  examples map to `tools["lazy-mcp"].invoke_command` on these servers. Production logs
  are RED data: summarize results, and don't paste raw documents into issues,
  MRs, or chat.
- For DevEx analytics data (CI pipelines and builds, test results, flaky tests,
  code coverage, and work item metrics), load the `devex-clickhouse` skill and
  query through the `clickhouse` MCP server. Load `clickhouse-best-practices`
  only to review ClickHouse schemas or queries. The skill links to
  `~/Developer/gitlab.com/gitlab-org/quality/analytics/team/.skills/clickhouse`,
  so update it with `git pull` in that clone. The server reads its credentials
  from `~/.config/lazy-mcp/clickhouse-username` and `clickhouse-password`, which
  `bootstrap.d/973-setup-clickhouse-credentials.sh` caches from 1Password.
  The skill's `clickhouse_run_select_query` is the `run_query` command in
  current `mcp-clickhouse` releases.
- For unknown server names, follow the
  [MCP discovery rules](tool-usage.md#mcp-server-names).
- Load [GDK dotfiles guidance](gdk-dotfiles.md) when working with personal files
  synced into `$GDK_ROOT/gitlab`.
- For GDK jobs on Compute Engine, load the [Compute Engine runbook](gdkbox-gcp.md)
  before provisioning. Stop on timeout, recover results, then delete resources.

Work-only skills live in `~/.agents/skills.work`, loaded through `skills`
in the Work branch of `opencode.json##template`. Keep their links out of the automatically
discovered shared skill directories. See [skill loading](opencode.md#skill-loading).
