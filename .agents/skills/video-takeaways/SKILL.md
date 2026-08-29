---
name: video-takeaways
description: "Video URLs and YouTube links: extract actionable takeaways with timestamp hyperlinks, then save approved notes to Memos or another requested destination. Use when asked to summarize learnings, lessons, rules of thumb, or practical advice from a video, talk, tutorial, or interview."
version: 1.0.0
license: MIT
compatibility: opencode
metadata:
  author: pedropombeiro
  audience: general
---

# Video takeaways

Turn a captioned video into concise, actionable, source-linked notes. Write the
notes in English, even when the video uses another language.

## When to use

- The user provides a video URL and asks for learnings, takeaways, notes, a
  checklist, or rules of thumb.
- The user wants each takeaway linked to the relevant point in the video.
- The user wants the result saved to Memos or another note destination.

## When not to use

- The user only wants to discuss the video conversationally.
- The user provides authoritative text and asks you to summarize that text.
- The task requires visual analysis that captions cannot support. Explain the
  limitation instead of inferring visual details from the transcript.

## Workflow

1. Run [`scripts/fetch-transcript`](scripts/fetch-transcript) instead of trying
   to retrieve a YouTube transcript with `webfetch`.
2. Follow [`references/WORKFLOW.md`](references/WORKFLOW.md) to identify topics,
   verify claims, and map each takeaway to a caption timestamp.
3. Draft the complete English summary for the user. Group advice by theme, use
   actionable language, and append a timestamp hyperlink to every takeaway.
4. Ask for confirmation before writing to Memos. If the user explicitly asks
   for another destination, use that destination instead.
5. After confirmation, save the draft and verify the stored content. Follow
   [`references/MEMOS-API.md`](references/MEMOS-API.md) when using Memos.

## Output contract

- Start with an H1 title and a source line that links to the original video.
- Group related takeaways under descriptive H2 headings rather than following
  the video's chronology.
- Express actions as imperatives or concrete checks. Preserve useful numbers,
  constraints, exceptions, and warning signs from the source.
- Append one or more timestamp links to every takeaway, for example:

  ```markdown
  - Lower the saddle in 3-4 mm steps, then reassess. ([21:21](https://www.youtube.com/watch?v=VIDEO_ID&t=1281s))
  ```

- Attribute subjective thresholds and recommendations to the speaker or video.
  Do not present one person's advice as universal consensus.
- If automatic captions make a term or number uncertain, omit it, qualify it,
  or retain the original-language term in parentheses.
- End every Memos summary with `#video-takeaways` so all summaries are easy to
  find. Add other relevant `#hashtags` on the same line.

## Language and destination

- Always write the notes in English. Translate for meaning rather than word for
  word.
- Default to a private Memos memo after the user approves the draft.
- Honor an explicit request to use a local file, repository document, or other
  destination.
- Do not publish, share, or make a memo public unless the user explicitly asks.

## Dependencies

The transcript helper requires `yt-dlp`, `jq`, and `perl`. If captions are not
available, report that clearly. Do not silently substitute an unverified
summary from video metadata or search results.

## When captions are unavailable

1. Report the helper's exact failure and distinguish no captions from a
   requested-language mismatch.
2. If other caption languages are available, list them and ask whether to use
   one. Do not translate from an unapproved fallback track.
3. If no captions exist, ask whether the user wants audio transcription. State
   which transcription tool you propose and any download, cost, privacy, or
   accuracy implications.
4. Do not download the video or audio, invoke speech-to-text, summarize video
   metadata, or use third-party transcript sites without explicit approval.
5. If the user declines a fallback, stop. Explain that timestamped takeaways
   require a transcript or another time-aligned source.
