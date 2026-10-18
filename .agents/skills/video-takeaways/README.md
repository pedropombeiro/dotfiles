# Video takeaways

`video-takeaways` is an OpenCode skill that turns captioned videos into concise,
actionable notes with links to the relevant timestamps. After you approve the
notes, the skill can write a Markdown file, save them to
[Memos](https://www.usememos.com/), send them to
[Wallabag](https://wallabag.org/) for an e-reader to sync, or produce any
combination of these outputs.

## Features

- Downloads creator-provided or automatic captions with `yt-dlp`.
- Organizes takeaways by topic instead of transcript order.
- Links every takeaway to the relevant point in the video.
- Supports videos and output notes in different languages.
- Writes standalone Markdown files without output-specific dependencies.
- Saves approved notes to an optional Memos instance.
- Sends approved notes to an optional Wallabag instance, with the video
  thumbnail as the cover. Re-sending a summary updates the existing entry.
- Keeps Memos and Wallabag hosts, credentials, and output destinations
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
   chmod +x scripts/fetch-transcript scripts/list-memo-tags scripts/send-to-wallabag
   ```

3. Install the core dependencies:

   - Bash
   - `yt-dlp`
   - `jq`
   - Perl

4. Install dependencies for the outputs you plan to use.

   - For Memos, install `curl` and configure an OpenCode Model Context Protocol
     (MCP) server for Memos.
   - For Wallabag, install `curl` and Pandoc.

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

## Configure Wallabag

Wallabag is optional. Create a dedicated API client in Wallabag, then store its
credentials in `~/.config/wallabag/credentials.env` with mode 600. To use
another file, pass `--env-file` or set `WALLABAG_ENV_FILE`. The
[Wallabag output reference](references/WALLABAG.md) lists the required keys.

## Use the skill

Give OpenCode a video URL and describe the result you want. For example:

```text
Summarize the actionable takeaways from this video and link each one to its
timestamp: VIDEO_URL
```

OpenCode drafts the notes for review. After approval, choose **Markdown**,
**Memo**, **Wallabag**, or any combination. If you request an output in the
initial prompt, the skill uses that choice without asking again.

You can also run the helpers directly:

```bash
scripts/fetch-transcript VIDEO_URL
scripts/send-to-wallabag summary.md
scripts/send-to-wallabag memos/MEMO_ID
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
- Selecting the Wallabag output approves sending the summary.
- The skill doesn't publish memos or make them public without an explicit
  request.

## Documentation

- [`SKILL.md`](SKILL.md) defines when an agent loads the skill and how it behaves.
- [`references/WORKFLOW.md`](references/WORKFLOW.md) describes transcript review
  and takeaway composition.
- [`references/MEMOS.md`](references/MEMOS.md) describes the optional Memos
  adapter.
- [`references/WALLABAG.md`](references/WALLABAG.md) describes Wallabag setup,
  entry contents, and verification.

## License

This skill is available under the MIT License.
