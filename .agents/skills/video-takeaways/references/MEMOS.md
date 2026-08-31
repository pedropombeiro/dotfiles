# Memos output reference

Use the `memos` MCP server to store approved video notes when the user selects
Memo output.

Memos support is optional. Do not assume a particular host, username, token
path, or default visibility. For scripts, configure access with CLI flags first,
then environment variables:

```text
--base-url URL       MEMOS_BASE_URL
--token-file PATH    MEMOS_TOKEN_FILE
```

Never accept a raw token as a command-line argument. Read it from a file and
pass the authorization header to `curl --config -` through standard input so it
does not appear in process arguments.

The helper scripts reject empty tokens and tokens containing whitespace,
quotes, or backslashes. These characters can split or alter a `curl` config
directive. A normal trailing newline in the token file is accepted.

## Discover tools

Use the environment's configured `memos` MCP server. Do not assume that a
specific MCP client or wrapper is installed. Inspect the available tools and
their input schemas before invoking them.

When `lazy-mcp` is available, follow its discovery sequence:

1. List commands for the `memos` server.
2. Describe commands that have not already been invoked successfully in the
   current session.
3. Invoke the command with the described parameter shape.

When the environment exposes Memos tools directly, use its native tool listing
or schema inspection instead. If no `memos` server is configured, explain that
Memo output is unavailable and offer Markdown or EPUB output instead.

The relevant operations create, update, and retrieve a memo. Tool names vary by
MCP client; names such as `memo_create_memo`, `memo_update_memo`, and
`memo_get_memo` are examples, not commands to invoke without discovery.

## Create a memo

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
shape. Use the visibility requested by the user. When none is specified,
prefer `PRIVATE` rather than publishing notes implicitly.

Memos extracts tags from hashtags in the Markdown content. The response's
`tags` field is output-only, so do not send it in the request. Every video
summary must include `#video-takeaways`; use additional tags for its subject.

## Add the video thumbnail

The transcript helper prints `thumbnail_url=URL` when a thumbnail is available.
Put the thumbnail directly below the H1 and link it to the source video:

```markdown
# Video title

[![Video thumbnail](THUMBNAIL_URL)](VIDEO_URL)
```

The current Memos MCP attachment API does not reliably preserve
`externalLink`, and passing large base64 image content through the tool is
fragile. Use the linked Markdown image instead. Thumbnail failure is non-fatal;
save the approved summary and report that the source did not provide a usable
thumbnail.

If attachment uploads become reliable later, add image resampling before
uploading bytes. Cap the long edge and JPEG quality rather than storing the
largest source thumbnail unchanged.

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
the timestamp links, exposes `video-takeaways` among the extracted tags, and
contains the expected linked thumbnail when one was available.
