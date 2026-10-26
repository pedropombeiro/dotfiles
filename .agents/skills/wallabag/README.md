# Wallabag

`wallabag` is an OpenCode skill that sends content to
[Wallabag](https://wallabag.org/) so an e-reader can sync it. It posts local
documents and provides the shared posting helper for other skills, such as
`video-takeaways`.

## Features

- Converts Google Docs HTML ZIP exports and Markdown files into clean
  Wallabag entries.
- Replaces Google redirect links with their targets.
- Replaces local images with matching images from a public original, and
  marks images that have no public copy.
- Posts Markdown or HTML with a title, author, language, tags, and cover.
  Re-sending the same URL updates the existing entry.
- Verifies that Wallabag stored the supplied content instead of fetching the
  URL.
- Lists existing tags so new entries reuse them.

## Install the skill

1. Copy or clone this directory to an OpenCode skill location:

   ```text
   ~/.agents/skills/wallabag/
   ```

2. Ensure the helper scripts are executable:

   ```bash
   chmod +x scripts/wallabag scripts/prepare-document
   ```

3. Install Bash, `curl`, `jq`, Perl, Pandoc, and Python 3.

4. Restart OpenCode so it discovers the installed skill.

## Configure Wallabag

Create a dedicated API client in Wallabag, then store its credentials in
`~/.config/wallabag/credentials.env` with mode 600. The
[API helper reference](references/API.md#set-up-access) lists the required
keys.

## Use the skill

Give OpenCode a local document and ask to send it to Wallabag. For example:

```text
Send this Google Docs export to Wallabag. The original article is
https://example.com/article: ~/Downloads/article.zip
```

OpenCode prepares the document, shows the title, URL, tags, and image results,
and sends it after you confirm.

You can also run the helpers directly:

```bash
scripts/prepare-document --source-url URL ~/Downloads/article.zip
scripts/wallabag post --url URL --author AUTHOR --tag TAG article.md
scripts/wallabag tags
```

Run any helper with `--help` for all options.

## Documentation

- [`SKILL.md`](SKILL.md) defines when an agent loads the skill and how it
  behaves.
- [`references/API.md`](references/API.md) describes setup, posting options,
  output, and troubleshooting.
- [`references/DOCUMENTS.md`](references/DOCUMENTS.md) describes document
  conversion, image handling, and entry URLs.

## License

This skill is available under the MIT License.
