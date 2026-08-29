# Memos API reference

Use the `memos` MCP server to store approved video notes. Memos is the default
destination, but the user can request another destination.

## Discover commands

Follow the required MCP sequence:

1. Call `lazy-mcp_list_commands` for the `memos` server.
2. Call `lazy-mcp_describe_commands` for commands that have not already been
   invoked successfully in the current session.
3. Call `lazy-mcp_invoke_command` with the described parameter shape.

The relevant commands are usually `memo_create_memo`, `memo_update_memo`, and
`memo_get_memo`.

## Create a private memo

Pass `content` and `visibility` inside `body`:

```json
{
  "body": {
    "content": "# Video title\n\n...\n\n#video-takeaways #topic",
    "visibility": "PRIVATE"
  }
}
```

Do not pass `visibility` as a top-level parameter. The server rejects that
shape. Omitting visibility also defaults to `PRIVATE`, but setting it explicitly
documents the intended access level.

Memos extracts tags from hashtags in the Markdown content. The response's
`tags` field is output-only, so do not send it in the request. Every video
summary must include `#video-takeaways`; use additional tags for its subject.

## Update an existing memo

`memo_update_memo` requires the memo resource, body, and update mask:

```json
{
  "memo": "memos/MEMO_ID",
  "updateMask": "content",
  "body": {
    "content": "# Updated video title\n\n..."
  }
}
```

Use the full resource name returned by the create operation. Do not include
read-only fields from a prior response in the update body.

## Verify the write

Call `memo_get_memo` with the full resource name:

```json
{
  "memo": "memos/MEMO_ID"
}
```

Confirm that the stored memo is private, contains the complete draft, retains
the timestamp links, and exposes `video-takeaways` among the extracted tags.
