# Tool Usage

Tool discovery and recovery from failed file operations.

## MCP server names

- When a server name is unknown, discover it with `lazy-mcp_list_servers` rather than guessing from the product name.
- A `describe_commands` batch containing an invalid name can fail to return schemas
  for valid names too. Rediscover the command names before retrying.

## PinchTab browser

PinchTab requires Google Chrome. If Chrome is unavailable, resolve its installation
or configuration rather than substituting another browser.

## Truncated file-tool arguments

If a large file operation fails with a JSON parse error and visibly incomplete
arguments, inspect the file before retrying. Split the operation at section
boundaries using the available file-editing tool, then verify the complete result.
Keep harness-specific workarounds here rather than copying them into project docs.

## Preserve non-ASCII characters

Use the available file-editing tool for replacements rather than `sed -i`.
Inspect the diff for unrelated changes. If glyphs render ambiguously, compare the
affected bytes with `hexdump -C` against the pre-edit content. Restore damaged
characters from that content rather than retyping lookalike glyphs.
