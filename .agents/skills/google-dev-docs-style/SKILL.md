---
name: google-dev-docs-style
description: Apply the Google Developer Documentation Style Guide, reconciled with Pedro's writing-style.md. Use when drafting, editing, or reviewing READMEs, docs, wikis, API references, tutorials, procedures, release notes, merge request descriptions, review comments, issue updates, or other technical prose.
metadata:
  source: https://developers.google.com/style
  authority: ~/.agents/docs/writing-style.md
---

# Google developer documentation style

Write clear, accessible technical prose by applying the [Google Developer
Documentation Style Guide](https://developers.google.com/style) with Pedro's
local conventions as the higher-priority style layer.

## Authority order

Apply guidance in this order:

1. Explicit user instructions and repository-specific guidance.
2. [`~/.agents/docs/writing-style.md`](../../docs/writing-style.md).
3. This skill's Google style guidance.
4. Established usage in the document or product.

This order follows Google's own reference hierarchy, which puts project-specific
style ahead of the Google guide. Prefer clarity and consistency when no source
settles a question.

For GitLab artifacts, including merge request descriptions, review comments,
issues, and team messages, read `~/.agents/docs/writing-style.md` before drafting.
It contains required templates, collaboration conventions, and posting rules
that this skill doesn't duplicate.

## Pedro overrides

Apply these rules even when Google recommends something different:

- Never use an em dash, an en dash, or a double hyphen as punctuation. Use a
  single dash (`-`) or rewrite the sentence.
- In GitLab prose, use `**bold**` for key terms and emphasis when it improves
  scanning. In product documentation, reserve bold for UI elements and run-in
  headings unless repository guidance says otherwise.
- First-person plural is acceptable when it clearly means Pedro's team or
  organization and supports a collaborative tone.
- Use precise product terminology such as `CLI` when it is established in the
  project. Don't apply Google's product-specific substitutions mechanically.
- Use backticks extensively for code identifiers, file paths, commands, labels,
  and other technical literals.

See [the override reference](references/overrides.md) for the rationale and Vale
mapping.

## Core rules

1. Write for the reader. Use `you` for the reader and the imperative for steps.
2. Prefer active voice and present tense. Name the actor when it matters.
3. Put conditions, context, and goals before instructions.
4. Use simple, precise words. Avoid jargon, idioms, slang, humor, excessive
   claims, and culturally specific references.
5. Keep paragraphs focused on one idea. Put the most important information
   first and break up walls of text.
6. Use sentence case for headings. Start task headings with a base-form verb and
   conceptual headings with a noun phrase. Don't start headings with an `-ing`
   verb when a direct alternative exists.
7. Use numbered lists for sequences, bullets for nonsequential items, and
   description lists for term-description pairs. Keep items parallel.
8. Use the serial comma. Avoid semicolons, ellipses, slashes, parentheses, and
   exclamation marks when a clearer sentence works.
9. Use descriptive link text that makes sense out of context. Never use `click
   here`, `this document`, or a bare URL as link text.
10. Put code-related literals in code font and UI elements in bold. Use
    `UPPER_SNAKE_CASE` placeholders and explain each placeholder.
11. Write inclusively and accessibly. Avoid ableist or divisive terminology,
    directional references, and information conveyed only through images,
    color, or position.
12. Make only claims that readers can verify. Don't promise future features or
    claim that a product is always secure, fastest, easiest, or guaranteed.

## Workflow

When drafting or revising technical prose:

1. Identify the artifact, audience, task, and repository-specific rules.
2. For GitLab prose, load `~/.agents/docs/writing-style.md`.
3. Draft for task completion before polishing style.
4. Apply the core rules and the relevant reference page:
   - [Language and grammar](references/language-and-grammar.md)
   - [Punctuation](references/punctuation.md)
   - [Document structure](references/structure.md)
   - [Code and links](references/code-and-links.md)
5. Run `scripts/vale-google` when a local file is available. Treat its output as
   editorial advice, not an automatic rewrite mandate.
6. Review the final text for project terminology, factual accuracy, and Pedro's
   voice. Resolve false positives in favor of the authority order.

## Review output

When reviewing prose, report the highest-impact findings first. For each
finding, include:

- The original wording or a precise location.
- The violated guideline.
- A replacement that preserves the author's meaning.

Don't rewrite established technical terms merely to satisfy a generic rule.
Don't post or submit reviewed prose without explicit user approval.

## Quick check

Before delivering prose, verify that:

- The purpose and next action are clear near the beginning.
- Conditions appear before instructions.
- Sentences use active voice and present tense where practical.
- Headings use sentence case and describe their sections.
- Procedures use numbered steps with an imperative verb near the start.
- Lists use parallel grammar and consistent punctuation.
- Links have descriptive text.
- Code, placeholders, and UI elements use the correct formatting.
- Claims are factual, inclusive, accessible, and suitable for a global audience.
- No banned dash punctuation, filler, or avoidable jargon remains.

## Source scope

The reference pages summarize the Google guide as read in August 2026. For an
edge case or a rule that might have changed, consult the live
[Google Developer Documentation Style Guide](https://developers.google.com/style).
