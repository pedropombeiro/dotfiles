# Tool Usage

Tool discovery and recovery from failed file operations.

## MCP server names

- When a server name is unknown, discover it with
  `tools["lazy-mcp"].list_servers({ filter })` rather than guessing from the product
  name.
- When discovering an undocumented server's commands in Code Mode, chain
  `list_commands({ server })` and `describe_commands({ server, command_names })` in
  one `execute` call by filtering the returned command names before describing them.
- A `describe_commands` batch containing an invalid name can fail to return schemas
  for valid names too. Rediscover the command names before retrying.

## Shell approval prompts

When using GitLab Duo models, batch independent checks into one turn. Use parallel
tool calls when possible, and separate checks only when a later check needs an
earlier result.

Shell commands that aren't pre-approved, such as multi-line scripts and heredocs,
each trigger a separate security prompt. Combine related steps, for example
build, upload, and commit, into one command chained with `&&`, rather than
running them as consecutive commands. Prefer the file tools for reads and edits,
since they don't prompt.

## PinchTab browser

PinchTab requires Google Chrome. The NAS has no local browser, so don't offer local
browser automation or an interactive sign-in there. Confirm that a browser is
available in the execution environment before proposing browser-based work. On the
NAS, prefer a supported API or ask the user to complete the UI step on their device.
Installing or configuring a browser requires separate approval. Don't substitute
another browser for Chrome.

## Truncated file-tool arguments

If a large file operation fails with a JSON parse error and visibly incomplete
arguments, inspect the file before retrying. Split the operation at section
boundaries using the available file-editing tool, then verify the complete result.
Keep harness-specific workarounds here rather than copying them into project docs.

## Formatter rewrites on edit

OpenCode's edit and write tools run the configured formatter on save. In the GitLab
repository, RuboCop autocorrect rewrites lines that `.rubocop_todo` exempts, so a
one-line factory edit can reformat unrelated code. `Developer/gitlab.com/opencode.jsonc##class.Work`
and `$GDK_ROOT/gitlab/opencode.jsonc` disable the `rubocop` and `standardrb`
formatters on save. In isolated checkouts without those configs, check
`git diff --stat` after editing Ruby files; if unrelated lines changed, restore the
file and apply the edit from the shell with an exact-match Ruby `sub!` that aborts
when nothing matches.

## Preserve non-ASCII characters

Use the available file-editing tool for replacements rather than `sed -i`.
Inspect the diff for unrelated changes. If glyphs render ambiguously, compare the
affected bytes with `hexdump -C` against the pre-edit content. Restore damaged
characters from that content rather than retyping lookalike glyphs.
