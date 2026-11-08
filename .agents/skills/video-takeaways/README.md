# Video takeaways

`video-takeaways` is an OpenCode skill that turns captioned videos into concise,
actionable notes with links to the relevant timestamps. After you approve the
notes, the skill can write a Markdown file, send them to
[Readeck](https://readeck.org/) for an e-reader or phone to sync, or both.

## Features

- Downloads creator-provided or automatic captions with `yt-dlp`.
- Organizes takeaways by topic instead of transcript order.
- Links every takeaway to the relevant point in the video.
- Supports videos and output notes in different languages.
- Writes standalone Markdown files without output-specific dependencies.
- Sends approved notes to an optional Readeck instance, with the video
  thumbnail as the cover. Re-sending a summary replaces the existing bookmark.
- Reuses existing tags when tagging new summaries.
- Keeps the Readeck host, credentials, and output destinations configurable.

## Install the skill

1. Copy or clone this directory to an OpenCode skill location:

   ```text
   ~/.agents/skills/video-takeaways/
   ```

   OpenCode also discovers skills under `.opencode/skills/` in a project and
   `~/.config/opencode/skills/` globally.

2. Ensure the helper scripts are executable:

   ```bash
   chmod +x scripts/fetch-transcript scripts/send-to-readeck
   ```

3. Install the core dependencies:

   - Bash
   - `yt-dlp`
   - `jq`
   - Perl

4. For Readeck output and tag lookup, install the `readeck` skill next to this
   one, at `~/.agents/skills/readeck/`, along with its dependencies.

5. Restart OpenCode so it discovers the installed skill.

## Configure Readeck

Readeck is optional. Create a dedicated API token in Readeck, then store it in
`~/.config/readeck/credentials.env` with mode 600. To use another file, pass
`--env-file` or set `READECK_ENV_FILE`. The `readeck` skill's
[API helper reference](../readeck/references/API.md#set-up-access) lists the
required keys.

## Use the skill

Give OpenCode a video URL and describe the result you want. For example:

```text
Summarize the actionable takeaways from this video and link each one to its
timestamp: VIDEO_URL
```

OpenCode drafts the notes for review. After approval, choose **Markdown**,
**Readeck**, or both. If you request an output in the
initial prompt, the skill uses that choice without asking again.

You can also run the helpers directly:

```bash
scripts/fetch-transcript VIDEO_URL
scripts/send-to-readeck summary.md
scripts/send-to-readeck --list-tags
```

Run any helper with `--help` for all options.

## Output behavior

- Markdown files go to `$HOME/Downloads` when that directory is writable.
  Otherwise, they go to the current directory.
- Existing Markdown files aren't overwritten. Automatic filenames receive a
  numeric suffix.
- Readeck doesn't deduplicate URLs, so sending the same summary again replaces
  the existing bookmark. The new bookmark keeps the labels, favorite, and archive
  state, but not the reading progress or highlights.
- Selecting Readeck output approves sending the summary.
- Tag lookups always use Readeck. If a lookup fails, continue without the tag
  inventory and report the failure.

## Documentation

- [`SKILL.md`](SKILL.md) defines when an agent loads the skill and how it behaves.
- [`references/WORKFLOW.md`](references/WORKFLOW.md) describes transcript review
  and takeaway composition.
- [`references/READECK.md`](references/READECK.md) describes how summaries map
  to Readeck bookmarks and how the helper verifies them.

## License

This skill is available under the MIT License.
