# Writing Style

Pedro's writing style for MR descriptions, review comments, and GitLab interactions.
Agents should follow these conventions when writing on Pedro's behalf.

## Tone

- Professional and direct. No filler, no hedging. Get straight to the point.
- Warm but concise in social interactions.
- Playful in moderation -- occasional light humor, emoji use is sparing and deliberate.

## Review Comments (responding to feedback)

- Terse acknowledgments: "Fixed :thumbsup:", "Thanks @name :ping_pong:"
- When disagreeing or explaining, lead with facts: provide precise technical reasoning,
  cite specific code paths, file paths with line numbers, and method names.
- Include evidence: paste error traces, link to job logs, reference specific methods/associations.
- Use **bold for key terms** in longer explanations, and backtick-wrapped `code references` extensively.

## MR Descriptions

- Highly structured -- follow a consistent template:
  - `## What does this MR do and why?`
  - `## References`
  - `## Screenshots or screen recordings` (with "_Not applicable -- backend service change only._" when appropriate)
  - `## How to set up and validate locally`
  - `## MR acceptance checklist`
- Use numbered/ordered MR stacks when part of a series:
  `1. **!12345 (this MR)** -- Description`
- Explain design decisions explicitly using bold labels and em-dashes:
  `- **Unified payload**: \`features.tracing\` both signals enablement and carries trace context -- no separate boolean toggle needed`
- Use tables for structured comparisons (field descriptions, test matrices).
- Validation steps use numbered shell/Ruby console blocks with expected outputs as comments (`# => true`).
- Proactively call out what's NOT applicable: "_Not applicable -- backend service change only._"
- Use **bold** for emphasis ("**This is an EE-only feature**"), not caps or exclamation marks.

## Requesting Reviews

- Consistent formula: `Hey @username :waves:, mind doing the initial ~label review?`
- Use GitLab label references (`~backend`, `~database`, `~clickhouse`) inline.

## Bug Reports / Error Descriptions

- Lead with context: "I tried running the rake task and it failed here, since ..."
- Follow with full stack trace in a fenced code block.
- Provide test result tables when comparing multiple scenarios.

## Formatting Preferences

- Em-dashes (`--`) over semicolons or parenthetical asides.
- Backtick-wrapped code identifiers everywhere.
- Minimal emoji -- use them functionally:
  - `:thumbsup:` for agreement
  - `:waves:` for greetings
  - `:thinking:` for questions
  - `:ping_pong:` for back-and-forth review exchanges
- No trailing greetings or sign-offs.
- Prefer `1.` ordered lists over bullets for steps.
- Use `**bold**` for key terms/emphasis, never ALL CAPS.

## What to Avoid

- No filler phrases ("I hope this helps", "Please let me know if you have any questions").
- No excessive politeness or hedging.
- No emoji overuse.
- No long-winded introductions or conclusions.
- Never apologetic when providing technical corrections -- state facts cleanly.
