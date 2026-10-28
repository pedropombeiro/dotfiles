# Readeck API helper reference

[`scripts/readeck`](../scripts/readeck) posts bookmarks through the Readeck API
and lists existing labels.

## Set up access

1. In Readeck, open **Profile** > **API Tokens** and create a token named
   `OpenCode`. Select both **Bookmarks: Read Only** and **Bookmarks: Write
   Only**. A dedicated token lets you revoke the skill's access without
   affecting other integrations.
2. Create the credentials file with mode 600:

   ```bash
   mkdir -p ~/.config/readeck
   touch ~/.config/readeck/credentials.env
   chmod 600 ~/.config/readeck/credentials.env
   ```

3. Add one `KEY=value` line for each setting:

   ```text
   READECK_URL=https://readeck.example.com
   READECK_TOKEN=TOKEN
   ```

   Replace `TOKEN` with the value that Readeck shows for the `OpenCode` token.

4. If a reverse proxy in front of Readeck requires a secret header, add the
   header name and value. Leave both lines out otherwise:

   ```text
   READECK_HEADER_NAME=HEADER_NAME
   READECK_HEADER_VALUE=HEADER_VALUE
   ```

   Both lines must be present together. Use the same name and value that the
   proxy matches, for example the ones the Readeck iOS app sends.

The helper reads `~/.config/readeck/credentials.env` by default. Use
`--env-file PATH` or `READECK_ENV_FILE` to choose another file. The helper
parses the file line by line and never sources it, so shell syntax in values
isn't evaluated. The file can contain blank lines and `#` comments, and the
helper removes matching outer quotes from values. The helper warns when other
users can read the file.

Agents must not create, read, or print the credentials file. Ask the user to
create it.

## Post a bookmark

```bash
scripts/readeck post --url URL [OPTIONS] FILE
```

`FILE` is a Markdown (`.md`) or HTML (`.html`) file. The helper converts
Markdown with `pandoc --from=gfm --to=html5`, removes the first H1 from the body,
and wraps the result in a page that carries the title, author, language, and
cover as metadata. An HTML file that already has an `<html>` element is sent as
it is.

| Option              | Purpose                                                                                          |
| ------------------- | ------------------------------------------------------------------------------------------------ |
| `--url URL`         | Required. Readeck stores it as the source URL and the helper uses it to find existing bookmarks. |
| `--title TITLE`     | Bookmark title. Defaults to the first Markdown H1.                                               |
| `--author AUTHOR`   | Bookmark author.                                                                                 |
| `--lang LANGUAGE`   | Bookmark language. Defaults to `en`.                                                             |
| `--tag TAG`         | Label to add. Repeat it or pass a comma-separated list.                                          |
| `--thumbnail IMAGE` | Cover image: an `http(s)` URL, or a local image file that the helper uploads.                    |
| `--expect TEXT`     | Fail unless the stored article contains `TEXT`.                                                  |
| `--replace`         | Replace existing bookmarks that have the same URL.                                               |
| `--timeout SECONDS` | Time to wait for Readeck to process the page. Defaults to 60.                                    |

The helper adds no labels of its own. Readeck uses the supplied HTML and
doesn't fetch the URL. The helper removes any `#fragment` from the URL, because
Readeck stores URLs without it and otherwise doesn't recognize the page it
received.

### Local images

Relative image paths in the file, such as `images/chart.png`, resolve against the
file's directory. The helper uploads each file with the bookmark, and Readeck
stores it. Absolute `http(s)` URLs stay as they are, and Readeck downloads those
images itself. The helper fails when a referenced file doesn't exist or isn't a
PNG, JPEG, GIF, WebP, or SVG image.

Use `--expect` with text that appears only in the supplied content, such as a
sentence near the end of a document or a timestamp parameter in a video
summary. A missing match means that Readeck used something other than the
supplied content.

### Failed sends

The helper removes the bookmark it created and exits with status 1 when:

- Readeck reports an extraction error or stores no article.
- Readeck doesn't finish within `--timeout` seconds.
- `--expect` doesn't match.

A failed send never removes a bookmark that existed before the command.

## List existing labels

```bash
scripts/readeck tags
```

Each line has the form `COUNT<TAB>LABEL`, most used first. Labels without
bookmarks don't appear.

## Re-send a bookmark

Readeck doesn't deduplicate URLs. Posting an existing URL again would create a
second bookmark, so the helper looks for bookmarks with the same URL first:

- Without `--replace`, the helper prints `existing_id` and fails.
- With `--replace`, the helper creates the new bookmark, copies the favorite and
  archive state, and adds the labels of the old bookmarks. Then it deletes the old
  bookmarks. If anything fails before that point, the old bookmarks stay.

A replacement is a new bookmark. It loses the reading progress and any highlights
of the old one, and it has no cover unless you pass `--thumbnail` again.

## Read the output

On success, the helper prints `key=value` lines:

| Key               | Value                                                         |
| ----------------- | ------------------------------------------------------------- |
| `entry_id`        | Readeck bookmark ID.                                          |
| `entry_url`       | `READECK_URL/bookmarks/ENTRY_ID`.                             |
| `source_url`      | URL stored by Readeck.                                        |
| `title`           | Stored title.                                                 |
| `author`          | Stored authors, comma-separated.                              |
| `language`        | Stored language code.                                         |
| `tags`            | Stored labels, comma-separated.                               |
| `cover`           | Stored cover image URL, or `none`.                            |
| `archived`        | `true` when the bookmark is archived.                         |
| `content_length`  | Length of the stored article HTML, in characters.             |
| `images_uploaded` | Local images sent with the bookmark, including a local cover. |
| `replaced`        | IDs of the bookmarks removed by `--replace`, or `none`.       |
| `validation`      | `passed` when `--expect` matched, otherwise `skipped`.        |

## Troubleshoot errors

The helper reports the HTTP status and any error message from Readeck:

- **HTTP 000:** the helper couldn't reach `READECK_URL`. Check the URL and the
  network.
- **HTTP 401:** Readeck rejected the token. Create a new one.
- **HTTP 403:** the token lacks the **Bookmarks: Read Only** or **Bookmarks:
  Write Only** scope, or a firewall, such as CrowdSec AppSec on an external
  router, blocked the request after inspecting the HTML body.
- **HTTP 404 with no message:** a reverse proxy that requires a secret header
  matched no router. Set `READECK_HEADER_NAME` and `READECK_HEADER_VALUE`.
- **HTTP 422:** Readeck rejected a field. The message names it, for example
  `url: invalid URL`.

## Security

- The helper passes the token and the optional header to `curl` through
  `--config -`, on standard input. No secret appears in process arguments.
- The helper rejects control characters, double quotes, and backslashes in the
  URL, token, and header values.
- Temporary files live in a private directory under `$TMPDIR`. The helper
  deletes the directory on exit.
