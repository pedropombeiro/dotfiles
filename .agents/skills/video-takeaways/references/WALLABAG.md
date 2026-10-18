# Wallabag output reference

Use Wallabag to deliver approved summaries to an e-reader. The helper posts the
summary to Wallabag as an HTML entry. A reader client, such as the KOReader
Wallabag plugin, downloads the entry and Wallabag builds the EPUB during sync.

Selecting the Wallabag output approves sending the summary. Don't ask for a
second confirmation.

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
helper removes matching outer quotes from values. The helper warns when other users can read the
file.

Agents must not create, read, or print the credentials file. Ask the user to
create it.

## Send a summary

The helper accepts a local Markdown file, a full Memos URL, or a Memos resource:

```bash
scripts/send-to-wallabag summary.md
scripts/send-to-wallabag https://memos.example.com/memos/MEMO_ID
scripts/send-to-wallabag memos/MEMO_ID
```

For Memos inputs, configure access with `--base-url` and `--token-file`, or
`MEMOS_BASE_URL` and `MEMOS_TOKEN_FILE`, as described in the
[Memos output reference](MEMOS.md).

These flags override inferred values:

```text
--url URL            Entry URL
--title TITLE        Entry title
--author AUTHOR      Entry author
--lang LANGUAGE      Entry language (default: en)
--thumbnail URL      Cover image URL
--no-cover           Omit the cover image
```

## Entry contents

The helper derives the entry from the summary:

- **URL:** the video URL from the link on the thumbnail line, or else the first
  link on the `Source:` line. The helper fails when it finds neither and you
  don't pass `--url`.
- **Origin URL:** the memo URL, for Memos inputs only.
- **Title:** the H1.
- **Author:** the creator named in the trailing `Source:` metadata, else the
  `Source:` link text, else `Video Takeaways`.
- **Cover:** the thumbnail image URL, sent as `preview_picture`. The Wallabag
  EPUB export uses it as the cover when it exports a single entry.
- **Tags:** `video-takeaways`, plus the hashtags from the last non-blank line
  when that line contains only hashtags.
- **Content:** the remaining Markdown, converted with
  `pandoc --from=gfm --to=html5`. The helper removes the H1, the thumbnail line,
  and the final hashtag line, because the EPUB title page shows the title and
  the cover shows the thumbnail.

Wallabag uses the supplied HTML and doesn't fetch the video page when the
title, content, and URL are all non-empty. It cleans the HTML before storing it.

## Re-send a summary

Wallabag matches entries by URL. Sending a summary for the same video again
updates the existing entry and keeps its ID. The helper doesn't send `archive`,
so re-sending doesn't change the entry's read status. Wallabag adds new tags
but doesn't remove existing ones. `--no-cover` doesn't clear a cover that an
earlier send set.

## Security

- The helper builds the OAuth token request from environment variables passed
  only to `jq`, and pipes it to `curl`. The bearer token reaches `curl` through
  `--config -`. No secret appears in process arguments.
- Temporary files live in a private directory under `$TMPDIR`. The helper
  deletes the directory on exit.

## Troubleshoot errors

The helper reports the HTTP status and any error message from Wallabag:

- **HTTP 000:** the helper couldn't reach `WALLABAG_URL`. Check the URL and
  the network.
- **HTTP 400 or 401 on the token request:** Wallabag rejected the client ID,
  client secret, username, or password.
- **HTTP 403:** a web application firewall (WAF), such as CrowdSec AppSec on
  the external router, might have blocked the request after inspecting the
  HTML body.

## Verify the entry

On success, the helper prints `key=value` lines:

| Key          | Value                                                        |
| ------------ | ------------------------------------------------------------ |
| `entry_id`   | Wallabag entry ID.                                           |
| `entry_url`  | `WALLABAG_URL/view/ENTRY_ID`.                                |
| `source_url` | Entry URL stored by Wallabag.                                |
| `title`      | Stored title.                                                |
| `author`     | Stored author.                                               |
| `language`   | Stored language.                                             |
| `tags`       | Stored tags, comma-separated.                                |
| `cover`      | Cover image URL, or `none`.                                  |
| `archived`   | `true` when the entry is archived.                           |
| `validation` | `passed` when the stored content has the first timestamp.    |

The helper fails when the response has no entry ID, or when the stored content
lacks the first `t=SECONDSs` timestamp from the summary. A missing timestamp
means that Wallabag fetched the page instead of using the supplied content.
The helper reports `validation=skipped` when the summary has no timestamp links.

To check the e-reader result, sync the reader and open the entry. Confirm
that the cover shows the thumbnail, that the title page shows the title, author,
and video URL, and that the timestamp links open the video at the right time.

## Dependencies

Bash, `curl`, `jq`, Pandoc, and Perl.
