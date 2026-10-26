---
name: wallabag
description: "Send content to a Wallabag instance for e-reader sync, including local documents such as Google Docs HTML ZIP exports and Markdown files. Use when asked to post, send, save, or import a document or article into Wallabag, when another skill needs to post to Wallabag, or when listing existing Wallabag tags. Not for EPUB or PDF uploads, which Wallabag can't import."
version: 1.0.0
license: MIT
compatibility: opencode
metadata:
  author: pedropombeiro
  audience: general
---

# Wallabag

Post articles and documents to Wallabag as HTML entries. A reader client, such
as the KOReader Wallabag plugin, downloads each entry and Wallabag builds the
EPUB during sync.

## When to use

- The user wants a local document in Wallabag. Supported inputs are a Google
  Docs **Web Page (.html, zipped)** export and a Markdown file.
- Another skill, such as `video-takeaways`, needs to post content or list tags.
- The user asks which tags already exist in Wallabag.

## When not to use

- The input is an EPUB, PDF, or DOCX file. Wallabag can't import these formats,
  and this skill doesn't convert them yet. For Google Docs, suggest the
  **File > Download > Web Page (.html, zipped)** export instead.
- The user wants Wallabag to fetch a public URL by itself. Saving the URL in
  Wallabag directly is simpler.

## Helpers

- [`scripts/wallabag`](scripts/wallabag): posts a Markdown or HTML file and
  lists tags. [`references/API.md`](references/API.md) covers credentials,
  options, output, and troubleshooting.
- [`scripts/prepare-document`](scripts/prepare-document): converts a local
  document into Wallabag-ready Markdown and handles local images.
  [`references/DOCUMENTS.md`](references/DOCUMENTS.md) describes the
  conversion.

Other skills call `scripts/wallabag` through the sibling path
`../wallabag/scripts/wallabag` relative to their own skill directory.

## Send a local document

1. Run `scripts/prepare-document`. When the document has a public original,
   pass it with `--source-url` so matching public images replace local ones.
2. Read the prepared Markdown. Remove export clutter, such as internal
   notices, sharing links, bylines, dates, and paywall labels, and keep the
   first H1 as the title. Follow
   [`references/DOCUMENTS.md`](references/DOCUMENTS.md#clean-up-the-markdown).
3. Choose the entry URL as described in
   [`references/DOCUMENTS.md`](references/DOCUMENTS.md#choose-the-entry-url).
   When the document has no public source, ask the user before using a
   placeholder URL.
4. Choose tags. Run `scripts/wallabag tags` once per session and prefer
   existing tags. Use lowercase and hyphens for multi-word tags.
5. Show a summary and ask for confirmation before sending. Include the title,
   author, entry URL, cover, tags, and image results: matched, omitted, and
   dropped inline images.
6. After approval, run `scripts/wallabag post` with `--expect` set to a
   distinctive sentence from late in the document.
7. Report the printed `entry_url`, `tags`, `cover`, `content_length`, and
   `validation` values. Treat a nonzero exit status as a failed send.
8. Move the prepared files to the Trash. The output directory can contain
   private content.

## Rules

- Never create, read, or print the credentials file. If it's missing, ask the
  user to create it as described in [`references/API.md`](references/API.md).
- Don't assume a Wallabag host. The credentials file defines it.
- Don't upload local images to third-party hosts. Wallabag drops embedded
  `data:` images, so an image without a public URL becomes a note in the text.
- Treat documents marked private or internal as sensitive. Sending one to the
  user's own Wallabag is fine, but don't publish its content elsewhere.

## Dependencies

Bash, `curl`, `jq`, Perl, Pandoc, and Python 3.
