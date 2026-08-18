# Local overrides and precedence

Google's [reference hierarchy](https://developers.google.com/style#reference-hierarchy)
puts project-specific style before the Google guide. This skill treats
`~/.agents/docs/writing-style.md` as Pedro's project-specific style layer.

## Resolved conflicts

**Dash punctuation**: Google uses an unspaced em dash for a sentence break and
doesn't use en dashes. Pedro bans em dashes, en dashes, and double hyphens. Use
a single dash or rewrite the sentence.

**Bold emphasis**: Google reserves bold for UI elements and run-in headings.
Pedro uses bold for key terms in longer explanations. Follow Pedro in GitLab
prose. Follow Google in product documentation unless local guidance differs.

**First-person plural**: Google avoids first person except for a clearly named
organization. Pedro accepts collaborative `we`. Use it when the antecedent is
clear and it aids collaboration.

**Technical terms**: Google's word list contains Google-product substitutions.
Pedro preserves precise project terminology. Don't apply product-specific
substitutions outside their domain.

**Code formatting**: Google puts code-related literals in code font. Pedro uses
backticks more extensively. Apply Pedro's broader convention.

**Semicolons**: Both styles avoid semicolons when practical. Rewrite with a
period, comma, colon, or single dash.

**Exclamation marks**: Both styles avoid excessive exclamation marks. Use them
only in literals or rare celebratory content.

## Content ownership

Keep these rules in `writing-style.md` rather than duplicating them here:

- Merge request description templates.
- Review-response phrasing.
- Review-request formulas and GitLab label syntax.
- Functional emoji conventions.
- Bug-report evidence requirements.
- Drafting versus posting authorization.

Load that file before writing a GitLab artifact. Keeping those rules in one file
prevents the skill and the personal conventions from drifting apart.

## Vale mapping

The wrapper disables these Google checks:

- `Google.EmDash`: it permits Google's em-dash convention, which Pedro bans.
- `Google.FirstPerson` and `Google.We`: they conflict with intentional,
  collaborative first-person prose.
- `Google.WordList` and `Google.WordListCase`: they contain Google-product terms
  that can produce incorrect substitutions in GitLab and other projects.

The `Pedro.NoDashPunctuation` rule replaces `Google.EmDash` and reports an error
for em dashes, en dashes, and double hyphens in prose. Vale normally excludes
code spans and fenced code blocks from prose rules.

Keep `Google.Passive` enabled as a suggestion. It is useful during review but
can produce false positives, so don't rewrite a correct sentence solely to
satisfy it.
