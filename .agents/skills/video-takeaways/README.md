# Video takeaways

`video-takeaways` is an OpenCode skill that turns captioned videos into concise,
actionable notes with links to the relevant timestamps. After you approve the
notes, the skill can save them to [Memos](https://www.usememos.com/), create an
EPUB (electronic publication) file for Kindle, or do both.

## Features

- Downloads creator-provided or automatic captions with `yt-dlp`.
- Organizes takeaways by topic instead of transcript order.
- Links every takeaway to the relevant point in the video.
- Supports videos and output notes in different languages.
- Saves approved notes to an optional Memos instance.
- Creates reflowable EPUB 3 documents with an optional video-thumbnail cover.
- Keeps Memos hosts, credentials, and output destinations configurable.

## Install the skill

1. Copy or clone this directory to an OpenCode skill location:

   ```text
   ~/.agents/skills/video-takeaways/
   ```

   OpenCode also discovers skills under `.opencode/skills/` in a project and
   `~/.config/opencode/skills/` globally.

2. Ensure the helper scripts are executable:

   ```bash
   chmod +x scripts/fetch-transcript scripts/list-memo-tags scripts/create-epub
   ```

3. Install the core dependencies:

   - Bash
   - `yt-dlp`
   - `jq`
   - Perl

4. Install dependencies for the outputs you plan to use.

   - For Memos, install `curl` and configure an OpenCode Model Context Protocol
     (MCP) server for Memos.
   - For EPUB files, install Pandoc.
   - For EPUB covers, install ImageMagick. The helper supports ImageMagick 7
     `magick` and ImageMagick 6 `convert`.
   - For EPUB structural validation, install `unzip`.

5. Restart OpenCode so it discovers the installed skill.

## Configure Memos

Memos is optional. Set its base URL and the path to a file containing your
personal access token:

```bash
export MEMOS_BASE_URL="https://memos.example.com"
export MEMOS_TOKEN_FILE="$HOME/.config/memos/token"
```

You can instead pass `--base-url` and `--token-file` to the Memos-aware helper
scripts. Command-line flags take precedence over environment variables. The
scripts don't accept a raw token as an argument.

Your OpenCode configuration must also provide a `memos` MCP server when you want
the skill to create or verify memos. See the
[Memos output reference](references/MEMOS.md) for the expected workflow.

## Use the skill

Give OpenCode a video URL and describe the result you want. For example:

```text
Summarize the actionable takeaways from this video and link each one to its
timestamp: VIDEO_URL
```

OpenCode drafts the notes for review. After approval, choose **Memo**, **EPUB**,
or both. If you request an output in the initial prompt, the skill uses that
choice without asking again.

You can also run the helpers directly:

```bash
scripts/fetch-transcript VIDEO_URL
scripts/create-epub summary.md
scripts/create-epub memos/MEMO_ID
```

Run any helper with `--help` for all options.

## Output behavior

- EPUB files go to `$HOME/Downloads` when that directory is writable. Otherwise,
  they go to the current directory.
- Existing EPUB files aren't overwritten.
- A missing thumbnail or ImageMagick installation produces a coverless EPUB
  instead of failing the conversion.
- The skill doesn't publish memos or make them public without an explicit
  request.
- The skill doesn't email or upload EPUB files to Amazon. Sending a file to
  Kindle requires separate explicit approval.

## Documentation

- [`SKILL.md`](SKILL.md) defines when OpenCode loads the skill and how it behaves.
- [`references/WORKFLOW.md`](references/WORKFLOW.md) describes transcript review
  and takeaway composition.
- [`references/MEMOS.md`](references/MEMOS.md) describes the optional Memos
  adapter.
- [`references/EPUB.md`](references/EPUB.md) describes EPUB generation,
  validation, and Send to Kindle constraints.

## License

This skill is available under the MIT License.
