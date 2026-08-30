# Video takeaway workflow

Use this workflow to turn caption cues into verifiable, actionable notes.

## Choose outputs after approval

After the user approves the draft, use the `question` tool with multiple
selection enabled and offer **Memo** and **EPUB**, unless the user already chose
a destination explicitly.

- For Memo only, consult tags and follow `MEMOS.md`.
- For EPUB only, generate directly from the approved local Markdown draft.
- For both, save the memo first, then generate the EPUB from the canonical
  stored memo.

Never upload or email an EPUB without a separate explicit request.

## Consult existing tags for Memos

Before the first Memo output in a session, run:

```bash
scripts/list-memo-tags \
  --base-url https://memos.example.com \
  --token-file ~/.config/memos/token
```

Configure the helper using `--base-url` and `--token-file`, or
`MEMOS_BASE_URL` and `MEMOS_TOKEN_FILE`. Run it only once per session and reuse
its output for subsequent Memo outputs in the same conversation. Skip this step
when Memos is not selected.

Always include `#video-takeaways` and aim for 3-5 tags total. Prefer an existing
tag whenever its meaning fits, even if a narrower new tag seems attractive.
Create a new tag only when the inventory has no suitable concept, and identify
the proposed new tag when showing the draft to the user. Use lowercase and
hyphens for multi-word tags, and avoid near-synonyms such as introducing
`bikefit` when `cycling` already serves the same retrieval need.

## Fetch the transcript

Run the helper with the video URL:

```bash
scripts/fetch-transcript VIDEO_URL
```

Use `--lang LANGUAGE` when you need a specific caption track. For a selected
language, the helper prefers human-authored captions to automatic captions.
Without `--lang`, it tries the video's original language, then English, then the
first available track.

The helper prints video metadata, a JPEG thumbnail URL when available, and the
path to a tab-separated transcript. Each transcript row has this shape:

```text
SECONDS<TAB>HH:MM:SS<TAB>CAPTION_TEXT
```

Treat `caption_source=automatic` as a warning that names, technical terms, and
numbers may be incorrect.

## Handle missing captions

If the requested language is unavailable, the helper lists available manual
and automatic caption languages. Show those options to the user and ask before
using a different track.

If the video has no captions, stop before downloading media or attempting
speech-to-text. Ask whether the user wants audio transcription, and name the
tool you would use. Include relevant tradeoffs such as media download, local or
remote processing, cost, privacy, and reduced timestamp or terminology
accuracy. Proceed only after explicit approval.

Never replace transcript-based notes with a summary inferred from the title,
description, search results, or third-party transcript sites. Without a
time-aligned source, you cannot produce trustworthy timestamp links.

## Locate the useful sections

1. Search the TSV for domain terms, numbers, repeated recommendations, and
   transitions between topics.
2. Read a generous window around each match. A search hit identifies an anchor,
   not enough context to support a takeaway by itself.
3. Build a topic-to-timestamp table before drafting. Record the cue where the
   speaker starts explaining the point.
4. Cross-check important numbers against nearby cues and repeated mentions.

Targeted searches are usually better than loading a long transcript in full. A
50-minute automatic transcript can contain more than 1,000 cue lines.

## Write actionable notes

- Group takeaways by theme, not chronology.
- State what the reader should check, change, avoid, or measure.
- Include concrete values and conditions when the transcript supports them.
- Preserve the speaker's caveats and distinguish examples from general advice.
- Combine repeated discussion into one takeaway. Add multiple timestamp links
  when separate passages materially support the same point.
- Avoid padding the summary with introductions, anecdotes, sponsor segments, or
  claims that do not change what the reader should do.

Use timestamp URLs supported by the video host. For YouTube, convert the cue's
seconds field to this form:

```text
https://www.youtube.com/watch?v=VIDEO_ID&t=SECONDSs
```

Display the human-readable cue time as the link text:

```markdown
([13:40](https://www.youtube.com/watch?v=VIDEO_ID&t=820s))
```

Thematic organization means timestamps might not increase monotonically. That
is expected.

## Review before saving

Check the draft for these requirements:

- Every actionable bullet or numbered item has a timestamp link.
- Every link points near the start of the relevant explanation.
- Notes are in the agreed language and remain faithful to the source.
- Uncertain automatic-caption terms are qualified or omitted.
- Personal stories have not become general rules without support.
- The source title and URL are present.
- A Memos draft ends with `#video-takeaways` and any subject-specific tags.
- The draft uses 3-5 tags, reuses existing labels where possible, and identifies
  any proposed new tag.

Show the full draft to the user and ask for confirmation before saving it.

## Verify after saving

1. Read the stored memo or file again.
2. Confirm that Markdown links and hashtags survived unchanged.
3. For Memos, confirm that the linked Markdown thumbnail appears below the H1
   when the helper produced one.
4. Spot-check several saved timestamps against the TSV, including at least one
   near the beginning and one near the end.
5. Report the memo resource name or destination path to the user.

For EPUB output, also report the output path, file size, title, author,
language, cover state, and validation result produced by `scripts/create-epub`.

Remove temporary transcript files after the task when they are no longer
useful.
