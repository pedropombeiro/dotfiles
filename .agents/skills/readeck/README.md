# Readeck

`readeck` is an OpenCode skill that sends content to
[Readeck](https://readeck.org/) so the iOS app or an e-reader can show it. It
posts local documents and provides the shared posting helper for other skills,
such as `video-takeaways`.

## Features

- Converts Google Docs HTML ZIP exports and Markdown files into clean
  Readeck bookmarks.
- Replaces Google redirect links with their targets.
- Uploads local images with the bookmark, so the article shows them without a
  public copy.
- Posts Markdown or HTML with a title, author, language, labels, and cover.
- Verifies that Readeck stored the supplied content instead of fetching the
  URL.
- Replaces an existing bookmark on request, keeping its labels, favorite, and
  archive state.
- Lists existing labels so new bookmarks reuse them.
- Works through a reverse proxy that requires a secret header.

## Install the skill

1. Copy or clone this directory to an OpenCode skill location:

   ```text
   ~/.agents/skills/readeck/
   ```

2. Ensure the helper scripts are executable:

   ```bash
   chmod +x scripts/readeck scripts/prepare-document
   ```

3. Install Bash, `curl`, `jq`, Perl, Pandoc, and Python 3.

4. Restart OpenCode so it discovers the installed skill.

## Configure Readeck

Create a dedicated API token in Readeck, then store it in
`~/.config/readeck/credentials.env` with mode 600. The
[API helper reference](references/API.md#set-up-access) lists the required
keys and the optional proxy header.

## Use the skill

Give OpenCode a local document and ask to send it to Readeck. For example:

```text
Send this Google Docs export to Readeck. The original article is
https://example.com/article: ~/Downloads/article.zip
```

OpenCode prepares the document, shows the title, URL, labels, and image results,
and sends it after you confirm.

You can also run the helpers directly:

```bash
scripts/prepare-document ~/Downloads/article.zip
scripts/readeck post --url URL --author AUTHOR --tag LABEL article.md
scripts/readeck tags
```

Run any helper with `--help` for all options.

## Differences from the Wallabag skill

- Readeck doesn't deduplicate URLs, so re-sending needs `--replace`, which
  creates a new bookmark and deletes the old one.
- Local images are uploaded, so `prepare-document` has no `--source-url` option
  and never writes "image not available publicly" notes.
- Authentication uses one API token, not an OAuth client and a password.

## Documentation

- [`SKILL.md`](SKILL.md) defines when an agent loads the skill and how it
  behaves.
- [`references/API.md`](references/API.md) describes setup, posting options,
  output, and troubleshooting.
- [`references/DOCUMENTS.md`](references/DOCUMENTS.md) describes document
  conversion, image handling, and bookmark URLs.

## License

This skill is available under the MIT License.
