# Punctuation and text formatting

Sources:

- [Google punctuation guidance](https://developers.google.com/style#punctuation)
- [Google text-formatting summary](https://developers.google.com/style/text-formatting)

Pedro's no-em-dash rule overrides Google's dash guidance. See
[the override reference](overrides.md).

## Commas and colons

- Use the serial comma before the final `and` or `or` in a series of three or
  more items.
- Put a comma after an introductory word or phrase.
- Put a comma before a coordinating conjunction that joins two independent
  clauses, unless both clauses are very short.
- Don't put a comma between an independent clause and a dependent clause unless
  the sentence would otherwise be ambiguous.
- Put a comma before `which` when it begins a nonrestrictive clause.
- Don't put a comma before a causal `because` unless the clause is
  nonrestrictive.
- Use a colon to introduce closely related information.
- Before a list, write a complete introductory sentence and end it with a colon.
- In general, lowercase the first word after a colon. Capitalize it when it
  begins a heading, quotation, notice, or proper noun.

Recommended: `Locations are divided into zones, regions, and multi-regions.`

Not recommended: `Locations are divided into zones, regions and multi-regions.`

## Dashes and hyphens

- Pedro override: don't use an em dash, en dash, or double hyphen as
  punctuation. Use a single dash with spaces or rewrite with a comma, colon,
  period, or parentheses.
- Don't use a dash to separate a run-in heading from its description. Use a
  colon or period.
- Use a hyphen to combine words that readers should interpret as one modifier
  before a noun: `a well-designed app`.
- In general, don't hyphenate the same compound after a verb: `The app is well
designed.` Follow the dictionary for compounds that stay hyphenated.
- Don't hyphenate an `-ly` adverb with the word that it modifies.
- Use a hyphen for numeric ranges or write `from` and `to`. Don't mix the forms.
- Never put spaces around a hyphen.
- Hyphenate a number and a spelled-out unit when they modify a noun: `a
five-minute wait`.
- Don't hyphenate a number and an abbreviated unit. Use a nonbreaking space when
  needed: `200 GB disk`.
- Avoid compound modifiers longer than two words. Rewrite them after the noun.

Recommended: `from 8 to 20 files` or `8-20 files`

Not recommended: `from 8-20 files`

## Semicolons, parentheses, ellipses, and slashes

- Avoid semicolons. Use a period or rewrite the sentence when practical.
- Don't put important information in parentheses. Keep necessary parenthetical
  text short.
- Don't use parentheses for optional plurals such as `key(s)`.
- Avoid ellipses in prose and UI references.
- In a quotation, use three periods with one space before and after to show
  omitted text. Don't use the single ellipsis character.
- Avoid slashes outside code and paths. Use `and` or `or` instead of `and/or`.
- Don't use slash-based dates, abbreviations, or fractions.

Recommended: `You can export raw events, processed events, or both.`

Not recommended: `You can export raw and/or processed events.`

## Periods and quotation marks

- End complete sentences with periods. Don't end headings with periods.
- Use one space between sentences.
- Avoid exposed URLs. If a URL must end a sentence, put the period directly
  after it or place the URL on its own line without a period.
- Avoid exclamation points in concepts, references, and procedures.
- Use straight quotation marks and apostrophes, not curly characters.
- Use quotation marks sparingly. Don't add them around code font.
- In ordinary quotations, put commas and periods inside the closing quotation
  mark. For an exact literal string, keep punctuation outside the quotation
  marks unless it belongs to the string.
- Use double quotation marks normally and single quotation marks only for a
  quotation nested inside another quotation or code that requires them.

## Formatting summary

| Content                                                  | Formatting                                            |
| -------------------------------------------------------- | ----------------------------------------------------- |
| UI elements and run-in headings                          | `**bold**`                                            |
| Technical emphasis in GitLab prose                       | `**bold**`, following Pedro's override                |
| Defined terms and words as words                         | `_italic_`                                            |
| Book, movie, and other full-work titles                  | `_italic_` unless linked                              |
| Inline code, filenames, commands, values, and user input | `` `code` ``                                          |
| Code samples and terminal output                         | fenced code block                                     |
| Links                                                    | descriptive link text; underline through site styling |
| Placeholders                                             | `UPPER_SNAKE_CASE` in code font                       |

- In Google-style product documentation, use italics rather than bold for
  emphasis. Usually, rewrite so the words carry the emphasis without styling.
- In GitLab prose, Pedro's bold-emphasis convention takes precedence.
- Reserve underlining for links.
- Don't override font face, size, or color inline.
- Don't use `&` as a substitute for `and`, except when reproducing a UI label or
  code value.
