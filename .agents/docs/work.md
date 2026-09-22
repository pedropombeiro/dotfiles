# Work instructions

These instructions load through the Work OpenCode configuration.

- For GitLab documentation, runbooks, handbook content, or company knowledge,
  use Glean first. Prefer `chat` for synthesis and `search` for raw results.
- Use `glean_default` as the server name in `lazy-mcp_list_commands`,
  `lazy-mcp_describe_commands`, and `lazy-mcp_invoke_command`.
- For unknown server names, follow the
  [MCP discovery rules](tool-usage.md#mcp-server-names).
- Load [GDK dotfiles guidance](gdk-dotfiles.md) when working with personal files
  synced into `$GDK_ROOT/gitlab`.

Work-only skills live in `~/.agents/skills.work`, loaded through `skills.paths`
in `opencode.json##class.Work`. Keep their links out of the automatically
discovered shared skill directories. See [skill loading](opencode.md#skill-loading).
