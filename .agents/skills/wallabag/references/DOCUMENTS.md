# Local document reference

[`scripts/prepare-document`](../scripts/prepare-document) turns a local
document into Markdown that [`scripts/wallabag`](../scripts/wallabag) can post.

## Supported inputs

- **Google Docs HTML ZIP:** the **File > Download > Web Page (.html, zipped)**
  export. The ZIP must contain one HTML file and its `images/` directory.
- **Markdown:** a `.md` file. Relative image paths resolve against the file's
  directory, and remote images stay unchanged.

## Prepare the document

```bash
scripts/prepare-document [--source-url URL] [--output-dir DIR] FILE
```

The script performs these steps:

1. Extracts the ZIP and converts the HTML with
   `pandoc --from=html --to=gfm-raw_html --wrap=none`.
2. Replaces Google redirect links, such as
   `https://www.google.com/url?q=TARGET&...`, with `TARGET`.
3. Processes each local image as described in
   [Handle local images](#handle-local-images).
4. Writes `article.md` to the output directory. Without `--output-dir`, the
   script creates a private directory under `$TMPDIR`.

It prints `key=value` lines:

| Key                     | Value                                                   |
| ----------------------- | ------------------------------------------------------- |
| `markdown`              | Path to the prepared `article.md`.                      |
| `output_dir`            | Directory to move to the Trash after sending.           |
| `title`                 | First H1 in the prepared Markdown.                      |
| `source_candidates`     | Usable images found on the `--source-url` page.         |
| `images_matched`        | Local images replaced with public URLs.                 |
| `images_omitted`        | Local images replaced with a note.                      |
| `images_dropped_inline` | Inline images removed as layout artifacts.              |
| `images_remote`         | Images that already had a remote URL.                   |
| `image`                 | One line per image: `PATH<TAB>SIZE<TAB>STATUS<TAB>URL`. |
| `candidate`             | One line per public image: `SIZE<TAB>URL`.              |

Review the `candidate` lines when a match looks wrong. Every candidate should
be an article image, not a logo, avatar, or banner.

## Handle local images

Wallabag removes embedded `data:` images, so a local image needs a public URL
to appear in the entry.

With `--source-url`, the script reads the public page and collects its images
in page order. It reads each candidate's dimensions from a `_WIDTHxHEIGHT`
suffix in the URL, from the `width` and `height` attributes, or from the image
header. It skips candidates smaller than 100 pixels on either side, and
unwraps image-proxy URLs that embed the original URL.

The script also skips images that the page displays below 100 pixels through
`width`, `height`, or inline `style` values, and images whose `alt` text
mentions an avatar, logo, icon, or profile. Site chrome often uses large files
at a small display size. A 400x400 author avatar would otherwise match a
square chart in the article.

The script then walks the local images in document order. Each local image
matches the next unused candidate whose aspect ratio is within 2% of its own.
Matching preserves order, so a skipped candidate isn't reconsidered for later
images. Exports are often resized, so dimensions alone don't need to match.

Unmatched images become
`*[Image not available publicly. See the original article.]*`. Without
`--source-url`, they become `*[Image omitted.]*`.

Images no taller than 32 pixels are removed without a note. Google Docs
sometimes exports an inline symbol, such as a currency sign, as a thin image
strip. Check the surrounding sentence for each `dropped-inline` image and
restore the missing text if you can infer it with confidence. Otherwise,
mention it in the summary.

Paywalled sources usually expose only the images before the paywall. Expect
the remaining images to be omitted.

## Clean up the Markdown

Read the prepared Markdown before sending it, and edit it in place:

- Remove export clutter before the H1, such as "internal copy" notices and
  links to shared drives.
- Remove byline, date, and paywall label lines below the title. Pass the
  author with `--author` instead.
- Keep the subtitle, captions, and the article's own links.
- Keep exactly one H1. `scripts/wallabag` uses it as the title and removes it
  from the body.
- Add a final `Source: [PUBLICATION](URL)` line when the document has a public
  original.

Don't summarize or rewrite the article text.

## Choose the entry URL

Wallabag uses the entry URL as the identity. Choose it in this order:

1. The public URL of the original article, when the user provides it or the
   document clearly identifies it. Posting it updates any entry that Wallabag
   saved from that URL, which replaces paywalled content with the full text.
2. When no public source exists, ask the user. If they agree, use
   `https://local.invalid/SLUG`, where `SLUG` is the lowercase title with runs
   of other characters replaced by single hyphens. The `.invalid` domain never
   resolves, and the stable slug lets a re-send update the same entry.

## Choose a cover

Use the first matched public image as `--thumbnail`, unless the user prefers
another image or no cover. Don't pass a local path.
