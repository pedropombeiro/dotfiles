# EPUB output reference

Use EPUB 3 for Kindle-friendly, reflowable takeaway documents. EPUB preserves
headings, lists, and hyperlinks while allowing readers to change font size and
margins.

## Create an EPUB

The helper accepts a local Markdown file, a full Memos URL, or a Memos resource:

```bash
scripts/create-epub summary.md
scripts/create-epub https://memos.example.com/memos/MEMO_ID \
  --token-file ~/.config/memos/token
scripts/create-epub memos/MEMO_ID \
  --base-url https://memos.example.com \
  --token-file ~/.config/memos/token
```

For Memos inputs, use CLI flags or `MEMOS_BASE_URL` and `MEMOS_TOKEN_FILE`.
Local Markdown inputs do not require Memos configuration.

Metadata flags override inferred values:

```text
--title TITLE
--author AUTHOR
--lang LANGUAGE
--thumbnail URL_OR_PATH
--no-cover
```

The default output directory is `$HOME/Downloads` when it exists and is
writable, otherwise the current directory. Existing files are not overwritten;
automatic output names receive a numeric suffix.

## Cover processing

The helper detects the linked Markdown thumbnail below the H1. It uses
ImageMagick 7 `magick`, or ImageMagick 6 `convert`, to:

- Auto-orient the image.
- Preserve its aspect ratio.
- Cap both dimensions at 800 pixels without upscaling.
- Strip unnecessary metadata.
- Encode JPEG at quality 82.

The cover image line is removed from the book body to avoid displaying the
thumbnail twice. If no thumbnail exists, the download fails, or ImageMagick is
unavailable, the helper warns and creates a coverless EPUB.

## Pandoc conversion

The helper runs Pandoc with GitHub-Flavored Markdown input, EPUB 3 output, a
table of contents, and title, author, and language metadata. Do not reconstruct
the command ad hoc when the helper is available.

Timestamp links remain clickable when the Kindle has network connectivity.

## Validation

The helper verifies that Pandoc produced a non-empty file. When `unzip` is
available, it also validates the EPUB ZIP structure. It reports validation as
`skipped` rather than claiming success when `unzip` is absent.

Review the reported title, author, language, cover state, size, and output path
before delivery.

Author inference prefers a channel or creator named in trailing source metadata,
then source-link text, then `Video Takeaways`. Use `--author` when the source
line names a video title rather than its creator.

## Send to Kindle

Amazon accepts EPUB personal documents through Send to Kindle. Web uploads
support files up to 200 MB. Email delivery requires the sender address to be on
the Amazon account's approved personal-document sender list.

Creating an EPUB does not authorize uploading or emailing it. Ask for explicit
approval before sending a file to Amazon or any email address.

## Dependencies

- Required: Bash, Pandoc, `jq`, and Perl.
- Memos inputs and remote covers: `curl`.
- Cover processing: ImageMagick 7 `magick` or ImageMagick 6 `convert`.
- Structural validation: `unzip`.

Install dependencies with the target platform's package manager. Do not assume
Homebrew, a specific Linux distribution, or a particular NAS environment.
