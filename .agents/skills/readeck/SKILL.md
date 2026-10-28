---
name: readeck
description: "Send content to a Readeck instance for iOS and e-reader reading, including local documents such as Google Docs HTML ZIP exports and Markdown files. Use when asked to post, send, save, or import a document or article into Readeck, when another skill needs to post to Readeck, or when listing existing Readeck labels. Not for EPUB, PDF, or DOCX files, which Readeck doesn't import."
version: 1.0.0
license: MIT
compatibility: opencode
metadata:
  author: pedropombeiro
  audience: general
---

# Readeck

Post articles and documents to Readeck as bookmarks. Readeck stores the supplied
HTML and its images, so a reader client, such as the Readeck iOS app or the
KOReader Readeck plugin, shows the content as sent.

## When to use

- The user wants a local document in Readeck. Supported inputs are a Google
  Docs **Web Page (.html, zipped)** export and a Markdown file.
- Another skill, such as `video-takeaways`, needs to post content or list labels.
- The user asks which labels already exist in Readeck.

## When not to use

- The input is an EPUB, PDF, or DOCX file. Readeck doesn't import these formats,
  and this skill doesn't convert them. For Google Docs, suggest the
  **File > Download > Web Page (.html, zipped)** export instead.
- The user wants Readeck to fetch a public URL by itself. Saving the URL in
  Readeck directly is simpler.

## Helpers

- [`scripts/readeck`](scripts/readeck): posts a Markdown or HTML file, uploads its
  local images, and lists labels. [`references/API.md`](references/API.md) covers
  credentials, options, output, and troubleshooting.
- [`scripts/prepare-document`](scripts/prepare-document): converts a local
  document into Readeck-ready Markdown and copies its local images next to it.
  [`references/DOCUMENTS.md`](references/DOCUMENTS.md) describes the conversion.

Other skills call `scripts/readeck` through the sibling path
`../readeck/scripts/readeck` relative to their own skill directory.

## Send a local document

1. Run `scripts/prepare-document`.
2. Read the prepared Markdown. Remove export clutter, such as internal
   notices, sharing links, bylines, dates, and paywall labels, and keep the
   first H1 as the title. Follow
   [`references/DOCUMENTS.md`](references/DOCUMENTS.md#clean-up-the-markdown).
3. Choose the bookmark URL as described in
   [`references/DOCUMENTS.md`](references/DOCUMENTS.md#choose-the-bookmark-url).
   When the document has no public source, ask the user before using a
   placeholder URL.
4. Choose labels. Run `scripts/readeck tags` once per session and prefer
   existing labels. Use lowercase and hyphens for multi-word labels.
5. Show a summary and ask for confirmation before sending. Include the title,
   author, URL, cover, labels, and image results: embedded, missing, and dropped
   inline images.
6. After approval, run `scripts/readeck post` with `--expect` set to a
   distinctive sentence from late in the document. Add `--replace` only when the
   user wants to update a bookmark that already exists.
7. Report the printed `entry_url`, `tags`, `cover`, `content_length`,
   `images_uploaded`, and `validation` values. Treat a nonzero exit status as a
   failed send.
8. Move the prepared files to the Trash. The output directory can contain
   private content.

## Rules

- Never create, read, or print the credentials file. If it's missing, ask the
  user to create it as described in [`references/API.md`](references/API.md).
- Don't assume a Readeck host. The credentials file defines it.
- Local images go only to the user's own Readeck. Don't upload them to any other
  host.
- `--replace` deletes the existing bookmark after it creates the new one. The new
  bookmark keeps the old labels, favorite, and archive state, but not the reading
  progress or highlights. Use it only when the user asks to update a bookmark.
- Treat documents marked private or internal as sensitive. Sending one to the
  user's own Readeck is fine, but don't publish its content elsewhere.

## Dependencies

Bash, `curl`, `jq`, Perl, Pandoc, and Python 3.
