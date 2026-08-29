# Video takeaway workflow

Use this workflow to turn caption cues into verifiable, actionable notes.

## Fetch the transcript

Run the helper with the video URL:

```bash
~/.agents/skills/video-takeaways/scripts/fetch-transcript VIDEO_URL
```

Use `--lang LANGUAGE` when you need a specific caption track. For a selected
language, the helper prefers human-authored captions to automatic captions.
Without `--lang`, it tries the video's original language, then English, then the
first available track.

The helper prints video metadata and the path to a tab-separated transcript.
Each transcript row has this shape:

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
- Advice is in English and remains faithful to the source.
- Uncertain automatic-caption terms are qualified or omitted.
- Personal stories have not become general rules without support.
- The source title and URL are present.
- A Memos draft ends with `#video-takeaways` and any subject-specific tags.

Show the full draft to the user and ask for confirmation before saving it.

## Verify after saving

1. Read the stored memo or file again.
2. Confirm that Markdown links and hashtags survived unchanged.
3. Spot-check several saved timestamps against the TSV, including at least one
   near the beginning and one near the end.
4. Report the memo resource name or destination path to the user.

Remove temporary transcript files after the task when they are no longer
useful.
