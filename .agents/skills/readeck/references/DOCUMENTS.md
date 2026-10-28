# Local document reference

[`scripts/prepare-document`](../scripts/prepare-document) turns a local
document into Markdown that [`scripts/readeck`](../scripts/readeck) can post.

## Supported inputs

- **Google Docs HTML ZIP:** the **File > Download > Web Page (.html, zipped)**
  export. The ZIP must contain one HTML file and its `images/` directory.
- **Markdown:** a `.md` file. Relative image paths resolve against the file's
  directory, and remote images stay unchanged.

## Prepare the document

```bash
scripts/prepare-document [--output-dir DIR] FILE
```

The script performs these steps:

1. Extracts the ZIP and converts the HTML with
   `pandoc --from=html --to=gfm-raw_html --wrap=none`.
2. Replaces Google redirect links, such as
   `https://www.google.com/url?q=TARGET&...`, with `TARGET`.
3. Processes each local image as described in
   [Handle local images](#handle-local-images).
4. Writes `article.md` and an `images/` directory to the output directory.
   Without `--output-dir`, the script creates a private directory under
   `$TMPDIR`.

It prints `key=value` lines:

| Key                     | Value                                                       |
| ----------------------- | ----------------------------------------------------------- |
| `markdown`              | Path to the prepared `article.md`.                          |
| `output_dir`            | Directory to move to the Trash after sending.               |
| `title`                 | First H1 in the prepared Markdown.                          |
| `images_embedded`       | Local images copied to `images/` for upload.                |
| `images_missing`        | Images whose file wasn't found, replaced with a note.       |
| `images_unsupported`    | Images with an unsupported file type, replaced with a note. |
| `images_dropped_inline` | Inline images removed as layout artifacts.                  |
| `images_remote`         | Images that already had a remote URL.                       |
| `image`                 | One line per image: `PATH<TAB>SIZE<TAB>STATUS<TAB>OUTPUT`.  |

## Handle local images

Readeck stores images that arrive with a bookmark, so a local image needs no
public URL. The script copies each local image to `images/N-NAME` in the output
directory and rewrites the Markdown to point at the copy. A file that the
document references more than once is copied once. `scripts/readeck post` uploads
the copies with the bookmark.

The script accepts PNG, JPEG, GIF, WebP, and SVG files. It replaces an image of
another type with `*[Image omitted: unsupported file type.]*`, and an image whose
file doesn't exist with `*[Image missing.]*`. It never copies other file types,
so a Markdown file can't pull an arbitrary file into the upload.

Images no taller than 32 pixels are removed without a note. Google Docs
sometimes exports an inline symbol, such as a currency sign, as a thin image
strip. Check the surrounding sentence for each `dropped-inline` image and
restore the missing text if you can infer it with confidence. Otherwise,
mention it in the summary.

## Clean up the Markdown

Read the prepared Markdown before sending it, and edit it in place:

- Remove export clutter before the H1, such as "internal copy" notices and
  links to shared drives.
- Remove byline, date, and paywall label lines below the title. Pass the
  author with `--author` instead.
- Keep the subtitle, captions, and the article's own links.
- Keep exactly one H1. `scripts/readeck` uses it as the title and removes it
  from the body.
- Add a final `Source: [PUBLICATION](URL)` line when the document has a public
  original.
- Replace each `*[Image missing.]*` note by fixing the source or by deleting the
  note, depending on whether the image matters.

Don't summarize or rewrite the article text.

## Choose the bookmark URL

Readeck stores the URL as the bookmark's source, and the helper uses it to find
existing bookmarks. Choose it in this order:

1. The public URL of the original article, when the user provides it or the
   document clearly identifies it. If Readeck already has a bookmark for that URL,
   the helper stops and reports `existing_id`. Pass `--replace` to swap the
   bookmark for the full document.
2. When no public source exists, ask the user. If they agree, use
   `https://local.invalid/SLUG`, where `SLUG` is the lowercase title with runs
   of other characters replaced by single hyphens. The `.invalid` domain never
   resolves, and the stable slug lets `--replace` find the same bookmark again.

The helper drops any `#fragment`, because Readeck stores URLs without it.

## Choose a cover

Use the first embedded image as `--thumbnail`, unless the user prefers another
image or no cover. Pass the absolute path of the copy, which is
`OUTPUT_DIR/images/N-NAME` for the `OUTPUT` shown on the `image` line, or a
public image URL. The helper uploads a local cover and sets it as the bookmark's
cover image.
