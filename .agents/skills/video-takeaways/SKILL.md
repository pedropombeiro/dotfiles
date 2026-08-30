---
name: video-takeaways
description: "Video URLs and YouTube links: extract actionable takeaways with timestamp hyperlinks, then save approved notes as Markdown, to Memos, as an EPUB for Kindle, or to another requested destination. Use when asked to summarize learnings, lessons, rules of thumb, practical advice, Markdown notes, EPUBs, or Send to Kindle documents from a video, talk, tutorial, or interview."
version: 1.0.0
license: MIT
compatibility: opencode
metadata:
  author: pedropombeiro
  audience: general
---

# Video takeaways

Turn a captioned video into concise, actionable, source-linked notes. Notes
default to English, even when the video uses another language.

## When to use

- The user provides a video URL and asks for learnings, takeaways, notes, a
  checklist, or rules of thumb.
- The user wants each takeaway linked to the relevant point in the video.
- The user wants the result saved to Memos, exported as an EPUB for Kindle, or
  written to another destination.

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
3. Draft the complete summary in the agreed language. Group advice by theme,
   use actionable language, and append a timestamp hyperlink to every takeaway.
4. After approval, use the `question` tool with multiple selection enabled to
   offer **Markdown**, **Memo**, and **EPUB**. Honor an explicit destination
   already chosen by the user without asking again.
5. For Markdown output, write the approved draft to a local `.md` file and
   verify it as described in [`references/WORKFLOW.md`](references/WORKFLOW.md).
6. For Memo output, consult existing tags once per session, then save and verify
   the note using [`references/MEMOS.md`](references/MEMOS.md).
7. For EPUB output, run [`scripts/create-epub`](scripts/create-epub) and follow
   [`references/EPUB.md`](references/EPUB.md). When Memo and EPUB are selected,
   save the memo first and create the EPUB from the canonical stored memo.

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
  find.
- Aim for 3-5 tags total, including `#video-takeaways`.
- Prefer an existing tag whenever one fits, even when a more specific label
  comes to mind. Propose a new tag only when no existing tag covers the topic,
  and identify it as new when presenting the draft.
- Use lowercase and hyphens for multi-word tags. Do not create a near-synonym
  of an existing tag.
- Put the video's thumbnail directly below the H1 as a linked Markdown image
  when the helper provides one. Link the image to the source video. Do not fail
  the summary when the source has no usable thumbnail.

## Language and destination

- Default to English, even when the video uses another language. Write in the
  video's original language, or another language, when the user asks. Translate
  for meaning rather than word for word.
- Memos is an optional output adapter. Do not assume a host, token path,
  username, or visibility.
- Markdown is an optional output adapter with no additional dependencies. Save
  it only when selected, unless another output needs a temporary Markdown source.
- EPUB is an optional output adapter. Generate it only when selected, and never
  upload or email it without separate explicit approval.
- Honor an explicit request to use a local file, repository document, or other
  destination.
- Do not publish, share, or make a memo public unless the user explicitly asks.

## Dependencies

The core transcript helper requires `yt-dlp`, `jq`, and Perl. Memos output also
requires `curl`; EPUB output requires Pandoc and optionally ImageMagick and
`unzip`. If captions are not available, report that clearly. Do not silently
substitute an unverified summary from video metadata or search results.

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
