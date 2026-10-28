# Readeck output reference

Use Readeck to deliver approved summaries to the Readeck iOS app or to an
e-reader. [`scripts/send-to-readeck`](../scripts/send-to-readeck) derives the
bookmark metadata from the summary and posts it through the shared `readeck`
skill helper at `../readeck/scripts/readeck`.

The `readeck` skill's [API helper reference](../../readeck/references/API.md)
covers credentials setup, re-sending, security, and troubleshooting. Agents must
not create, read, or print the credentials file.

Selecting the Readeck output approves sending the summary. Don't ask for a
second confirmation.

## Send a summary

Pass the helper a local Markdown file:

```bash
scripts/send-to-readeck summary.md
```

These flags override inferred values:

```text
--url URL            Bookmark URL
--title TITLE        Bookmark title
--author AUTHOR      Bookmark author
--lang LANGUAGE      Bookmark language (default: en)
--thumbnail URL      Cover image URL
--no-cover           Omit the cover image
--env-file PATH      Credentials file
```

List existing labels with `scripts/send-to-readeck --list-tags`.

## Bookmark contents

The helper derives the bookmark from the summary:

- **URL:** the video URL from the link on the thumbnail line, or else the first
  link on the `Source:` line. The helper fails when it finds neither and you
  don't pass `--url`.
- **Title:** the H1.
- **Author:** the creator named in the trailing `Source:` metadata, else the
  `Source:` link text, else `Video Takeaways`.
- **Cover:** the thumbnail image URL. Readeck downloads it and stores it as the
  bookmark's cover.
- **Labels:** `video-takeaways`, plus the hashtags from the last non-blank line
  when that line contains only hashtags.
- **Content:** the remaining Markdown, without the H1, the thumbnail line, and
  the final hashtag line.

## Re-send a summary

Readeck doesn't deduplicate URLs, so the helper always passes `--replace`.
Sending a summary for a video that already has a bookmark creates the new
bookmark, copies the favorite and archive state, adds the old labels, and deletes
the old bookmark. The new bookmark loses the reading progress and highlights of
the old one.

## Verify the bookmark

The helper passes the first `t=SECONDSs` timestamp from the summary to
`--expect`. A missing timestamp in the stored article means that Readeck didn't
use the summary, and the helper fails and removes the bookmark it created. The
helper reports `validation=skipped` when the summary has no timestamp links. See
the [output keys](../../readeck/references/API.md#read-the-output) for the other
printed values.

To check the reading result, open the bookmark in Readeck or sync the reader.
Confirm that the cover shows the thumbnail, that the title, author, and source
URL are right, and that the timestamp links open the video at the right time.
