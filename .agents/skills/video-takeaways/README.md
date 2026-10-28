# Video takeaways

`video-takeaways` is an OpenCode skill that turns captioned videos into concise,
actionable notes with links to the relevant timestamps. After you approve the
notes, the skill can write a Markdown file, send them to
[Wallabag](https://wallabag.org/) or [Readeck](https://readeck.org/) for an
e-reader or phone to sync, or any combination.

## Features

- Downloads creator-provided or automatic captions with `yt-dlp`.
- Organizes takeaways by topic instead of transcript order.
- Links every takeaway to the relevant point in the video.
- Supports videos and output notes in different languages.
- Writes standalone Markdown files without output-specific dependencies.
- Sends approved notes to an optional Wallabag or Readeck instance, with the
  video thumbnail as the cover. Re-sending a summary updates the existing Wallabag
  entry, or replaces the existing Readeck bookmark.
- Reuses existing tags when tagging new summaries.
- Keeps the Wallabag and Readeck hosts, credentials, and output destinations
  configurable.

## Install the skill

1. Copy or clone this directory to an OpenCode skill location:

   ```text
   ~/.agents/skills/video-takeaways/
   ```

   OpenCode also discovers skills under `.opencode/skills/` in a project and
   `~/.config/opencode/skills/` globally.

2. Ensure the helper scripts are executable:

   ```bash
   chmod +x scripts/fetch-transcript scripts/send-to-wallabag scripts/send-to-readeck
   ```

3. Install the core dependencies:

   - Bash
   - `yt-dlp`
   - `jq`
   - Perl

4. For Wallabag output, install the `wallabag` skill next to this one, at
   `~/.agents/skills/wallabag/`, along with its dependencies. For Readeck output,
   install the `readeck` skill at `~/.agents/skills/readeck/` the same way.

5. Restart OpenCode so it discovers the installed skill.

## Configure Wallabag

Wallabag is optional. Create a dedicated API client in Wallabag, then store its
credentials in `~/.config/wallabag/credentials.env` with mode 600. To use
another file, pass `--env-file` or set `WALLABAG_ENV_FILE`. The `wallabag`
skill's [API helper reference](../wallabag/references/API.md#set-up-access)
lists the required keys.

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
**Wallabag**, **Readeck**, or any combination. If you request an output in the
initial prompt, the skill uses that choice without asking again.

You can also run the helpers directly:

```bash
scripts/fetch-transcript VIDEO_URL
scripts/send-to-wallabag summary.md
scripts/send-to-wallabag --list-tags
scripts/send-to-readeck summary.md
scripts/send-to-readeck --list-tags
```

Run any helper with `--help` for all options.

## Output behavior

- Markdown files go to `$HOME/Downloads` when that directory is writable.
  Otherwise, they go to the current directory.
- Existing Markdown files aren't overwritten. Automatic filenames receive a
  numeric suffix.
- Wallabag entries use the video URL as their identity, so sending the same
  summary again updates the existing entry. A missing thumbnail produces an
  entry without a cover.
- Readeck doesn't deduplicate URLs, so sending the same summary again replaces
  the existing bookmark. The new bookmark keeps the labels, favorite, and archive
  state, but not the reading progress or highlights.
- Selecting the Wallabag or Readeck output approves sending the summary.

## Documentation

- [`SKILL.md`](SKILL.md) defines when an agent loads the skill and how it behaves.
- [`references/WORKFLOW.md`](references/WORKFLOW.md) describes transcript review
  and takeaway composition.
- [`references/WALLABAG.md`](references/WALLABAG.md) describes how summaries
  map to Wallabag entries and how the helper verifies them.
- [`references/READECK.md`](references/READECK.md) describes how summaries map
  to Readeck bookmarks and how the helper verifies them.

## License

This skill is available under the MIT License.
