# Document structure

Source: [Google formatting and organization guidance](https://developers.google.com/style#formatting-and-organization)

## Headings

- Use one unique level-1 heading per page.
- Use sentence case and don't add a period.
- Make every heading descriptive, unique, and followed by content.
- Don't skip heading levels or use heading tags for visual styling.
- Base the page title on the page's primary purpose.
- Start task headings with a base-form verb: `Create an instance`.
- Use a noun phrase for conceptual headings: `Migration to Google Cloud`.
- Don't start a heading with an `-ing` verb when a direct alternative exists.
- Prefix optional sections with `Optional:` rather than appending `(optional)`.
- Avoid links, numbering, and unexplained code items in headings.
- When a heading must contain code, add a descriptive noun beside the code item.

Recommended: `Create an instance`

Not recommended: `Creating an instance`

Recommended: `Optional: Customize your alias`

Not recommended: `Customize your alias (optional)`

## Paragraphs

- Cover one idea in each paragraph.
- Put the most important and distinguishing information first.
- Use the fewest words and sentences that preserve meaning.
- Treat five or six sentences as a signal to check whether the paragraph needs
  splitting. Keep a longer paragraph intact when every sentence supports one
  idea.
- Use one-sentence paragraphs when they improve comprehension.
- Left-align text. Don't center, justify, or force line breaks within prose.

## Lists

- Use a numbered list when sequence, priority, or rank matters.
- Use a bulleted list for nonsequential items.
- Use a description list for term-description pairs.
- Use a table when each item contains three or more related data points.
- Don't create a list with only one item.
- Introduce a list with a complete sentence that ends in a colon. Omit the
  introduction only when the heading supplies all required context.
- Don't write an introductory fragment that the items complete.
- Capitalize each item unless case carries technical meaning.
- Keep list items parallel in grammar and scope.
- End complete sentences with periods. Don't add periods to single words,
  verbless phrases, code-only items, or link-only items.
- If punctuation becomes inconsistent, rewrite the items or punctuate all of
  them consistently.
- Don't end an example list with `etc.` or `and so on`. Introduce it as a
  non-exhaustive list instead.
- In run-in headings, use bold followed by a colon or period. Don't use a dash.

Recommended introduction: `To get the USB driver, follow these steps:`

Not recommended: `To get the USB driver:`

## Procedures

- Format a procedure as numbered steps.
- Introduce most procedures with a sentence that adds context beyond the
  heading. Don't repeat the heading.
- Format a single-step procedure as one bulleted sentence.
- Put one action in each step when practical.
- Begin the first sentence of each step with or near an imperative verb.
- Use complete sentences and parallel verb forms.
- Put the tool, UI location, condition, or goal before the action.
- Put the action before its result or justification.
- Write optional steps as `Optional: ...`.
- Combine short sequential menu selections with `>`: `Click **File** > **New**
  > **Document**.`
- If a step contains substeps, use lowercase letters, then lowercase Roman
  numerals.
- If several methods work, document the accessible, shortest, and simplest one.
- Link to an existing procedure instead of repeating it.
- Include prerequisites before readers begin and minimize interruptions in the
  task flow.
- Don't use `please`, directional descriptions, or keyboard shortcuts.
- Introduce a command by stating its purpose, not with `Run the following
command`.

Recommended: `In the Google Cloud console, go to the **Monitoring** page.`

Not recommended: `Go to the **Monitoring** page in the Google Cloud console.`

Recommended: `In Cloud Shell, deploy the load generator:`

Not recommended: `Run the following command:`

## Tables

- Use a table for genuinely two-dimensional data, not page layout or a long
  one-dimensional list.
- Convert a one-column table to a list.
- Avoid tables in the middle of numbered procedures.
- Introduce every table with a complete sentence that states its purpose.
- Use sentence case and concise column headings without punctuation.
- Use actual heading cells for the first row and first column. Add appropriate
  `scope` attributes in HTML.
- Don't merge cells or use visual styling alone to communicate headers.
- Sort rows in a logical order or alphabetically when no logical order exists.
- Split complicated tables that require multiple header rows or columns.
- Use captions when several tables appear close together. Number the tables and
  refer to each by number.
- Don't communicate new information through images or symbols alone.

## Notices

- Use notices sparingly because readers often skip content outside the main
  flow.
- Use a note only for relevant information that readers don't need to complete
  the task.
- Use a caution when readers must proceed carefully.
- Use a warning for an irreversible or severe consequence, such as data loss,
  financial loss, lost work, or a security breach.
- Don't use a note for prerequisites, required steps, cross-references, or
  expected results.
- Don't stack notices or nest one notice inside another. Reorganize the content.
- Prefer regular prose when the information belongs in the task flow.

## Numbers, dates, and units

- Spell out zero through nine in ordinary prose. Use numerals for 10 and above.
- Always use numerals for technical quantities, versions, measurements, times,
  dates, percentages, and steps.
- Spell out a number that begins a sentence or rewrite the sentence.
- Spell out ordinal numbers in prose.
- Use a comma for thousands and a period for decimals in US English.
- Use an unambiguous date with the month spelled out: `January 3, 2026`.
- Include the year unless the context makes it unnecessary and remains valid.
- Use a 12-hour clock with `AM` and `PM`, or use a consistently documented
  24-hour clock. Include the time zone when readers might be in several zones.
- Put a space between a number and an abbreviated unit: `64 GB`.
- Don't pluralize an abbreviated unit: `64 GB`, not `64 GBs`.
- Use a nonbreaking space when the number and unit must stay together.
- Express ranges with one unit after the range when no ambiguity results:
  `10-20 MB`.

## Images and accessibility

- Give every meaningful image concise alt text that explains its purpose. Use
  empty alt text for decorative images.
- Explain in text every piece of information that an image communicates.
- Don't use images of text, source code, or terminal output.
- Prefer SVG for diagrams when practical.
- Don't rely on color, size, location, sound, animation, or punctuation alone
  to convey meaning.
- Provide captions or transcripts for audio and video. Avoid flashing content.
- Make all interactive elements reachable with a keyboard.
- Use semantic headings, lists, tables, buttons, and form labels.
- Test interactive documentation with a screen reader when practical.
