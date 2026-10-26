# Wallabag API helper reference

[`scripts/wallabag`](../scripts/wallabag) posts entries through the Wallabag
API and lists existing tags.

## Set up access

1. In Wallabag, open **API clients management** and create a client named
   `OpenCode`. A dedicated client lets you revoke the skill's access without
   affecting other integrations.
2. Create the credentials file with mode 600:

   ```bash
   mkdir -p ~/.config/wallabag
   touch ~/.config/wallabag/credentials.env
   chmod 600 ~/.config/wallabag/credentials.env
   ```

3. Add one `KEY=value` line for each setting:

   ```text
   WALLABAG_URL=https://wallabag.example.com
   WALLABAG_CLIENT_ID=CLIENT_ID
   WALLABAG_CLIENT_SECRET=CLIENT_SECRET
   WALLABAG_USERNAME=USERNAME
   WALLABAG_PASSWORD=PASSWORD
   ```

   Replace the following:

   - `CLIENT_ID` and `CLIENT_SECRET`: the values shown for the `OpenCode`
     client.
   - `USERNAME` and `PASSWORD`: the Wallabag account that owns the entries.

The helper reads `~/.config/wallabag/credentials.env` by default. Use
`--env-file PATH` or `WALLABAG_ENV_FILE` to choose another file. The helper
parses the file line by line and never sources it, so shell syntax in values
isn't evaluated. The file can contain blank lines and `#` comments, and the
helper removes matching outer quotes from values. The helper warns when other
users can read the file.

Agents must not create, read, or print the credentials file. Ask the user to
create it.

## Post an entry

```bash
scripts/wallabag post --url URL [OPTIONS] FILE
```

`FILE` is a Markdown (`.md`) or HTML (`.html`) file. The helper converts
Markdown with `pandoc --from=gfm --to=html5` and removes the first H1 from the
body, because the EPUB title page shows the title.

| Option             | Purpose                                                       |
| ------------------ | ------------------------------------------------------------- |
| `--url URL`        | Required. Wallabag uses the URL to identify the entry.        |
| `--title TITLE`    | Entry title. Defaults to the first Markdown H1.               |
| `--author AUTHOR`  | Entry author.                                                 |
| `--lang LANGUAGE`  | Entry language. Defaults to `en`.                             |
| `--tag TAG`        | Tag to add. Repeat it or pass a comma-separated list.         |
| `--thumbnail URL`  | Cover image URL, sent as `preview_picture`.                   |
| `--expect TEXT`    | Fail unless the stored content contains `TEXT`.               |

The helper adds no tags of its own. Wallabag uses the supplied HTML and
doesn't fetch the URL when the title, content, and URL are all non-empty. It
cleans the HTML before storing it, which removes embedded `data:` images.

Use `--expect` with text that appears only in the supplied content, such as a
sentence near the end of a document or a timestamp parameter in a video
summary. A missing match means that Wallabag fetched the URL instead.

## List existing tags

```bash
scripts/wallabag tags
```

Each line has the form `COUNT<TAB>TAG`, most used first. The inventory covers
every entry in the account. Tags without entries don't appear.

## Re-send an entry

Wallabag matches entries by URL. Posting the same URL again updates the
existing entry and keeps its ID. The helper doesn't send `archive`, so
re-sending doesn't change the read status. Wallabag adds new tags but doesn't
remove existing ones. Omitting `--thumbnail` doesn't clear an existing cover.

## Read the output

On success, the helper prints `key=value` lines:

| Key              | Value                                                  |
| ---------------- | ------------------------------------------------------ |
| `entry_id`       | Wallabag entry ID.                                     |
| `entry_url`      | `WALLABAG_URL/view/ENTRY_ID`.                          |
| `source_url`     | Entry URL stored by Wallabag.                          |
| `title`          | Stored title.                                          |
| `author`         | Stored author.                                         |
| `language`       | Stored language.                                       |
| `tags`           | Stored tags, comma-separated.                          |
| `cover`          | Cover image URL, or `none`.                            |
| `archived`       | `true` when the entry is archived.                     |
| `content_length` | Length of the stored HTML content, in characters.      |
| `validation`     | `passed` when `--expect` matched, otherwise `skipped`. |

## Troubleshoot errors

The helper reports the HTTP status and any error message from Wallabag:

- **HTTP 000:** the helper couldn't reach `WALLABAG_URL`. Check the URL and
  the network.
- **HTTP 400 or 401 on the token request:** Wallabag rejected the client ID,
  client secret, username, or password.
- **HTTP 403:** a web application firewall (WAF), such as CrowdSec AppSec on
  the external router, might have blocked the request after inspecting the
  HTML body.

## Security

- The helper builds the OAuth token request from environment variables passed
  only to `jq`, and pipes it to `curl`. The bearer token reaches `curl` through
  `--config -`. No secret appears in process arguments.
- Temporary files live in a private directory under `$TMPDIR`. The helper
  deletes the directory on exit.
