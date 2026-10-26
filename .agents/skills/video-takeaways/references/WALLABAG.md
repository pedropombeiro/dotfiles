# Wallabag output reference

Use Wallabag to deliver approved summaries to an e-reader.
[`scripts/send-to-wallabag`](../scripts/send-to-wallabag) derives the entry
metadata from the summary and posts it through the shared `wallabag` skill
helper at `../wallabag/scripts/wallabag`.

The `wallabag` skill's
[API helper reference](../../wallabag/references/API.md) covers credentials
setup, re-sending, security, and troubleshooting. Agents must not create,
read, or print the credentials file.

Selecting the Wallabag output approves sending the summary. Don't ask for a
second confirmation.

## Send a summary

Pass the helper a local Markdown file:

```bash
scripts/send-to-wallabag summary.md
```

These flags override inferred values:

```text
--url URL            Entry URL
--title TITLE        Entry title
--author AUTHOR      Entry author
--lang LANGUAGE      Entry language (default: en)
--thumbnail URL      Cover image URL
--no-cover           Omit the cover image
--env-file PATH      Credentials file
```

List existing tags with `scripts/send-to-wallabag --list-tags`.

## Entry contents

The helper derives the entry from the summary:

- **URL:** the video URL from the link on the thumbnail line, or else the first
  link on the `Source:` line. The helper fails when it finds neither and you
  don't pass `--url`.
- **Title:** the H1.
- **Author:** the creator named in the trailing `Source:` metadata, else the
  `Source:` link text, else `Video Takeaways`.
- **Cover:** the thumbnail image URL. The Wallabag EPUB export uses it as the
  cover when it exports a single entry.
- **Tags:** `video-takeaways`, plus the hashtags from the last non-blank line
  when that line contains only hashtags.
- **Content:** the remaining Markdown, without the H1, the thumbnail line, and
  the final hashtag line. The EPUB title page shows the title and the cover
  shows the thumbnail.

## Verify the entry

The helper passes the first `t=SECONDSs` timestamp from the summary to
`--expect`. A missing timestamp in the stored content means that Wallabag
fetched the video page instead of using the summary, and the helper fails. The
helper reports `validation=skipped` when the summary has no timestamp links.
See the [output keys](../../wallabag/references/API.md#read-the-output) for
the other printed values.

To check the e-reader result, sync the reader and open the entry. Confirm
that the cover shows the thumbnail, that the title page shows the title, author,
and video URL, and that the timestamp links open the video at the right time.
